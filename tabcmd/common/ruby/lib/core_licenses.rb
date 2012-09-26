# -----------------------------------------------------------------------
# The information in this file is the property of Tableau Software and
# is confidential.
#
# Copyright (c) 2010 Tableau Software, Incorporated
#                    and its licensors. All rights reserved.
# Protected by U.S. Patent 7,089,266; Patents Pending.
# 
# Portions of the code
# Copyright (c) 2002 The Board of Trustees of the Leland Stanford
#                    Junior University. All rights reserved.
# -----------------------------------------------------------------------
# common/ruby/lib/core_licenses.rb
# -----------------------------------------------------------------------

require 'active_record'

## CLASS CoreLicenses
## Manage the Rails DB records of per-machine requested and allocated core license counts.
##
class CoreLicenses < ActiveRecord::Base
  # The primary key is the machine IP address, so override the default :id key
  set_primary_key :machine_ip
  
  # Required for REST accesses, specifically for wgapp/app/controllers/licensing_controller.rb
  def name
    machine_ip
  end

  ##
  ## The following methods will NOT rethrow StandardError exceptions and its descendents.
  ##
  
  # Is there a database record of this machine having successfully acquired a license?
  def self.is_licensed?(machine_ip, machine_cores)
    # Do not expose StandardError exceptions to the caller -- assume unlicensed by default
    begin
      c_l = CoreLicenses.find_by_machine_ip_and_machine_cores(machine_ip, machine_cores)
      if c_l.nil?
        logger.debug "CoreLicenses.is_licensed?: No record exists for machine #{machine_ip}"
        return false
      end
      
      # Validate the license record
      return true if c_l.is_licensed?
    rescue StandardError => err
      log_exception(err)
    end
    logger.debug "CoreLicenses.is_licensed?: No valid record exists for machine #{machine_ip}"
    return false
  end

  # Compute the total number of cores which have been allocated to workers.
  def self.total_allocated_cores
    begin
      return self.total_allocated_cores_impl
    rescue StandardError => err
      log_exception(err)
    end
    logger.error("CoreLicenses.total_allocated_cores: Unable to query the core_licenses table.")
    return 0
  end
  
  # Attempt to acquire a license for this machine
  def self.acquire_license(machine_ip, machine_cores, capacity_cores)
    logger.debug "CoreLicenses: Acquiring license for machine #{machine_ip} with core count #{machine_cores}"
    begin
      # Look up or create the record as needed
      c_l = CoreLicenses.lookup(machine_ip, machine_cores)
      CoreLicenses.transaction do
        # Lock the record for updates
        c_l.lock_nowait!
        
        # Erase the current allocation so we get a valid total allocation below
        c_l.allocated_cores = 0
        c_l.save!
        
        avail_cores = capacity_cores - total_allocated_cores_impl
        logger.debug "CoreLicenses: Available capacity: #{avail_cores}"

        # Cores are allocated as All-or-nothing
        c_l.allocated_cores = (avail_cores >= machine_cores) ? machine_cores : 0
        c_l.machine_cores = machine_cores
        c_l.update_timestamp!
        c_l.save!        
      end
      
      # Finally perform one more sanity check that we have a valid capacity. If we are
      # over capacity, it means another acquisition completed its transaction after we
      # checked the total allocation count. Invalidate our current acquisition since
      # the customer has more cores than capacity.
      if (c_l.is_licensed? && !capacity_valid?(capacity_cores))
        logger.debug "CoreLicenses: Abandoning the current acquisition. Another acquisition request completed before the current one, and the cluster is now at capacity."
        c_l.allocated_cores = 0
        c_l.save!
      end
      logger.debug "CoreLicenses: Successfully allocated #{machine_cores} cores to #{machine_ip}" if c_l.is_licensed?
      return c_l.is_licensed?

    #B47179 Meaningful error message when a machine's cores are more than what the product key contains
    rescue ArJdbc::PostgreSQL::RecordNotUnique => err
      logger.debug  "ArJdbc::PostgreSQL::RecordNotUnique"  
	
    rescue ActiveRecord::StaleObjectError, ActiveRecord::StatementInvalid
      # Another acquisition on the same machine may have completed, causing the row
      # lock above to fail. Report success if the machine appears to be licensed.
      # $NOTE-rmorton-2010-04-28:  When it comes to licensing, a delayed success is
      # better than an immediate failure.
      # B29727: Rescue StatementInvalid as well, since a collision may occur within
      # 'lookup' on attempting to create a new record currently with another process
      # on the same machine.
      retries = 3
      while retries > 0 && !is_licensed?(machine_ip, machine_cores)
        sleep 1
        retries = retries - 1
      end
      return is_licensed?(machine_ip, machine_cores)
  
    rescue StandardError => err
      log_exception(err)
    end
    
    return false
  end
  
  # Attempt to refresh the license record timestamp for this machine
  def self.refresh_license(machine_ip, machine_cores)
    logger.debug "CoreLicenses: Refreshing license record timestamp for machine #{machine_ip} with core count #{machine_cores}"
    begin
      c_l = CoreLicenses.find_by_machine_ip_and_machine_cores(machine_ip, machine_cores)
      if c_l.nil?
        logger.debug "CoreLicenses.refresh_license: No valid record exists for machine #{machine_ip}"
        return
      end
      
      # Touch the license record
      c_l.update_timestamp!
      c_l.save!
    rescue StandardError => err
      log_exception(err)
    end
  end
  
  # Validate that the allocated core count is not greater than the capacity
  def self.capacity_valid?(capacity_cores)
    begin
      return total_allocated_cores_impl <= capacity_cores
    rescue StandardError => err
      log_exception(err)
    end
    return false
  end
  
  # Perform all validation operations to ensure the core_licenses table is in a good state.
  def self.validate_license_database(capacity_cores, workers)
    begin
      # Purge all licenses if the allocated license count exceeds the total license capacity
      if (!capacity_valid?(capacity_cores))
        purge_all
      else
        # Purge licenses with a stale update timestamp
        purge_stale_licenses
        # Purge licenses which have an invalid state
        purge_invalid_licenses
        # Purge licenses for workers which are no longer part of the cluster
        purge_missing_workers(workers)
      end
    rescue StandardError => err
      log_exception(err)
      logger.warn "CoreLicenses.validate_license_database: Unable to perform license validation, purging all allocated licenses"
      purge_all
    end
  end

  # The age limit (fractional days) for allocated Core licenses before they are flushed as invalid.
  def self.age_limit
    0.5
  end

  # Purge all licenses -- typically used if the allocated core license
  # capacity exceeds licensed core capacity.
  def self.purge_all
    begin
      logger.debug "CoreLicenses: Purging all allocated licenses"
      # Find and delete records for missing workers
      CoreLicenses.transaction do
        delete_all
      end
      logger.debug "CoreLicenses: Done purging all"
    rescue StandardError => err
      log_exception(err)
    end
  end


  ##
  ## The following methods may expose exceptions to their callers
  ##
  
  # Validate that the allocated core count matches the machine core count
  def is_licensed?
    return allocated_cores == machine_cores
  end
  
  # Update the record timestamp explicitly by using 'current_timestamp', which
  # is evaluated remotely on the Rails DB using its machine clock. The Rails
  # auto-update mechanism is based on the client machine clock, which may not
  # be in sync across all workers.
  def update_timestamp!(query_text = "current_timestamp")
    self.class.connection.execute("UPDATE #{self.class.table_name} SET update_ts = #{query_text} WHERE machine_ip = '#{machine_ip}'")
  end
  
  def update_ts=(value)
    raise "Direct assignment is not supported for this field"
  end
  
  # Compute the total number of cores which have been allocated to workers.
  def self.total_allocated_cores_impl
    return sum('allocated_cores')
  end

  # Lookup or create a record for the given machine_ip
  def self.lookup(machine_ip, machine_cores)
    # Look up the existing record and lock for updates
    c_l = CoreLicenses.find_by_machine_ip(machine_ip)
    
    # Create a new record as needed and lock for updates
    if (c_l.nil?)
      c_l = CoreLicenses.new
      c_l.machine_ip = machine_ip
      c_l.machine_cores = machine_cores
      c_l.allocated_cores = 0
      c_l.save!
      c_l.update_timestamp!
      # $NOTE-rmorton-2010-05-08:  Based on investigating some strange log errors it
      # seems that the newly created object was causing an INSERT each time it was saved,
      # so to be certain replace the saved object with a lookup once it is created.
      #B47179 Meaningful error message when a machine's cores are more than what the product key contains
      #For some strange reson querying license again gives nil object.
      if(c_l.nil?)
         c_l = CoreLicenses.find_by_machine_ip(machine_ip)
      end
    end
    c_l
  end
  
  # Purge all licenses older than age_limit_days fractional days
  # as well as all licenses set in the future past age_limit_days.
  # While no "future allocations" of licenses are valid, we want to
  # allow some leeway with worker system time variations.
  def self.purge_stale_licenses(age_limit_days = CoreLicenses.age_limit)
    begin
      logger.debug "CoreLicenses: Purging stale licenses"
      # Delete records for all stale licenses
      CoreLicenses.transaction do
        delete_all("(current_timestamp - INTERVAL '#{age_limit_days} DAY') > update_ts OR " <<
                   "(current_timestamp + INTERVAL '#{age_limit_days} DAY') < update_ts OR " <<
                   "(update_ts IS NULL) AND allocated_cores <> 0")
      end
      logger.debug "CoreLicenses: Done purging stale licenses"
    #B43640 attempt to DELETE FROM core_licenses during tabadmin licenses fails.
    rescue ActiveRecord::StatementInvalid => err
      license_retrieve_error = "Warning: The machine could not retrieve a license"
      logger.debug err
      log_exception(Exception.new(license_retrieve_error))
    rescue StandardError => err
      log_exception(err)
    end
  end
  
  # Purge individual licenses which are invalid due to a mismatch between
  # the machine core count and the allocated core count, unless the 
  # allocated count is zero (preserve failed license requests).
  def self.purge_invalid_licenses
    begin
     logger.debug "CoreLicenses: Purging invalid licenses"
      # Find and delete records for all invalid licenses
      CoreLicenses.transaction do
        delete_all("allocated_cores < 0 OR allocated_cores > 0 AND machine_cores <> allocated_cores")
      end
      logger.debug "CoreLicenses: Done purging invalid licenses"
    rescue StandardError => err
      log_exception(err)
    end
  end

  # Purge individual licenses for worker machines which are no longer
  # part of the cluster.
  def self.purge_missing_workers(cluster_worker_ips)
    begin
      logger.debug "CoreLicenses: Purging licenses for missing workers"
      # Find and delete records for missing workers
      CoreLicenses.transaction do
        find(:all).each do |r|
          if !cluster_worker_ips.include?(r.machine_ip)
            logger.info "CoreLicenses: Worker with IP #{r.machine_ip} is no longer in the cluster, removing its allocated license."
            r.destroy
          end
        end
      end
      logger.debug "CoreLicenses: Done purging missing workers"
    rescue StandardError => err
      log_exception(err)
    end
  end

  # Request a non-blocking row-level lock
  def lock_nowait!
    begin
      reload(:lock => 'FOR UPDATE NOWAIT') unless new_record?
    rescue StandardError => err
      logger.debug "CoreLicenses.lock_nowait!: Unable to acquire row lock -- #{err.class.name}: #{err}"
      raise ActiveRecord::StaleObjectError
    end
  end


private

  def self.log_exception(err)
    msg = %Q[#{err.class.name}: #{err}\n#{(err.backtrace || []).join("\n")}]
    logger.error msg if logger
    puts msg if !logger
  end
  
end
