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
# app/lib/guidmaker.rb
# -----------------------------------------------------------------------

class GuidMaker
  require 'stateful_url_guid'

  attr_reader :logger

  BASE27 = "BCDFGHJKMNPQRSTWXYZ23456789"

  def initialize(len = 9)
    @length = len
    @alphabet = BASE27.split("").to_a
    @logger = Rails.logger
  end

  def rand_from_alphabet()
    @alphabet[rand(@alphabet.size)] # no special seeding or complexity needed
  end

  def generate()
    (0...@length).map{ rand_from_alphabet() }.join
  end

  def batch_generate(how_many = 1)
    ret = []
    how_many.times {ret << generate}
    ret
  end

  # factored out for easier mock/stub testing
  def guids_from_db(num)
    ret = []
    rs = StatefulUrlGuid.connection.execute("select guid from stateful_url_guids where used = false for update limit #{num}")
    0.upto(rs.size - 1) do |index|
      ret << rs[index]["guid"]
    end
    return ret.compact
  end

  def vector_to_comma_separated_string(vec)
    return vec.collect{|g| %Q['#{g}']}.join(',')
  end

  # factored out for easier mock/stub testing
  def mark_guids_used(guids)
    return if guids.nil? || guids.empty?
    guids_as_string = vector_to_comma_separated_string(guids)
    StatefulUrlGuid.connection.execute("update stateful_url_guids set used = true where guid in (#{guids_as_string})")
  end

  def obtain(how_many = 1)
    guids = []
    tries = 0
    while (guids.size < how_many && tries < AppConfig.guid.max_tries)
      begin
        tries += 1
        StatefulUrlGuid.transaction do
          guids += guids_from_db(how_many - guids.size)
          mark_guids_used(guids) unless guids.nil? || guids.empty?
        end
        if guids.size != how_many
          logger.debug("failed to obtain #{how_many} guids, only got #{guids.size} after #{tries} tries.  Trying to create more")
          msg = ensure_enough_spares(how_many - guids.size)
          logger.debug(msg)
        end
      rescue Exception => e
        logger.error("failed to obtain guids, try #{tries}.  #{e}")
        raise
      end
    end

    if tries >= AppConfig.guid.max_tries && guids.size < how_many
      raise GuidException.new("unable to obtain guids after #{tries} tries")
    end

    return guids
  end


  def mark_guids_unused(guids)
    processed = 0
    if guids && !guids.empty?
      StatefulUrlGuid.transaction do
        guids.each_slice(AppConfig.shared_view.reap_batch_size) do |guid_slice|
          guids_as_string = vector_to_comma_separated_string(guids)
          rs = StatefulUrlGuid.connection.execute("update stateful_url_guids set used = false where guid in (#{guids_as_string})")
          processed += rs
        end
      end
    end
    return processed
  end


    # factored out for testing
  def add_new_guids_to_db(fresh)
    StatefulUrlGuid.connection.execute(%Q[insert into stateful_url_guids (guid) values #{fresh.collect{|f| "('#{f}')" }.join(',')}])
  end

  # factored out for testing
  def free_guids_in_db
    ret = 0
    rs = StatefulUrlGuid.connection.execute(%Q[select count(*) from stateful_url_guids where used = false])
    if 0 < rs.size
      logger.debug("failed to get count for free_guids_in_db")
      ret = rs[0]["count"].to_i
    end
    return ret
  end

  def ensure_enough_spares(headroom)
    avail = free_guids_in_db()
    needed = headroom - avail
    made = 0
    tries = 0
    failure_count = 0
    fresh = []

    while (tries < AppConfig.guid.max_tries && free_guids_in_db() < headroom)
      begin
        tries += 1
        fresh = batch_generate(AppConfig.guid.batch_size) # we will always round up to batch_size on creation
        add_new_guids_to_db(fresh)
        made += fresh.length
      rescue StandardError => e
        ## note these go to backgrounder.log instead of log.txt because of RAILS_DEFAULT_LOGGER
        logger.warning("failed to insert new guids #{fresh.join(',')}, failure count is #{failure_count}")
        logger.warning("exception is #{e}")
        failure_count += 1
      end
    end

    success = made >= needed
    if !success
      raise GuidException.new("Failed to generate #{headroom} guids.  Only made #{made} in #{tries} attempts")
    else
      avail = free_guids_in_db()
      return "Generated #{made} guids in #{tries} tries.  #{avail} available"
    end

  end

end
