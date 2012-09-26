# -----------------------------------------------------------------------
# The information in this file is the property of Tableau Software and
# is confidential.
#
# Copyright (c) 2011 Tableau Software, Incorporated
#                    and its licensors. All rights reserved.
# Protected by U.S. Patent 7,089,266; Patents Pending.
#
# Portions of the code
# Copyright (c) 2002 The Board of Trustees of the Leland Stanford
#                    Junior University. All rights reserved.
# -----------------------------------------------------------------------

require 'hierstruct'
require 'pathname'
require 'settmp'
require 'singleton'
require 'yaml'
require 'java'

class AppConfigError < RuntimeError
end

class NoConfiguration < AppConfigError
end

class AppConfigFactory
  include Singleton

  def initialize
    _create_appconfig
    explicit_root_dir = java.lang.System.get_property("tableau.jar.root")
    if explicit_root_dir
      # if the incoming string is wrapped in single-quotes (bat-file horribleness), strip them
      explicit_root_dir = explicit_root_dir.gsub(/^'/,'').gsub(/'$/,'')
      @root_dir = Pathname.new(File.expand_path(explicit_root_dir + '/..'))
    else
      @root_dir = Pathname.new(File.expand_path(File.dirname(__FILE__)+'/../../..'))
    end
    self.config_root = @root_dir
    @worker_dir = @root_dir
    @config_name = nil
    @load_hooks = []
    @admin_root = nil
  end

  attr_reader :config_root, :config_name, :load_hooks

  def root_dir
    @root_dir
  end

  # Set the workgroup root directory
  def root_dir=(dir)
    @root_dir = Pathname.new(dir).expand_path
    self.config_root = dir
  end

  def config_root=(dir)
    @config_root = _find_data_dir(dir)
  end

  def worker_dir
    @worker_dir
  end

  def admin_root
    @admin_root ? @admin_root : worker_dir + "admin"
  end

  def admin_root=(dir)
    @admin_root = Pathname.new(dir).expand_path
  end

  def load_by_name(config_name)
    load_config_yamls(config_name)
    @config_name = config_name
  end

  def load_config_yamls(arg)
    begin
        file = Pathname.new(config_path(arg))
        raw_yaml = file.read
        config_hash = (raw_yaml.length > 0) ? YAML::load(raw_yaml) : nil

        file = Pathname.new(connections_path(arg))
        raw_yaml = file.read
        config_hash = (raw_yaml.length > 0) ? config_hash.merge!(YAML::load(raw_yaml)) : config_hash

      _set_defaults_for_worker(config_hash)
      AppConfig.replace(config_hash)
      @load_hooks.each { |h| h.call(AppConfig) }
    rescue StandardError => ex
      msg = "#{ex.class}: #{ex.message}\n#{ex.backtrace.join("\n")}"
      if defined?(logger) && !logger.nil?
        logger.debug(msg)
      else
        $stderr.puts(msg) unless 'true' == ENV['SILENCE_APPCONFIG_LOAD_ERRORS']
      end
      raise NoConfiguration, "Failed to load configuration#{' from ' << file.expand_path }"
    end
  end

  # load the configuration from a hash or a file
  def load(arg)
    begin
      if arg.kind_of?(Hash)
        config_hash = arg
      else
        file = Pathname.new(arg)
        raw_yaml = file.read
        config_hash = (raw_yaml.length > 0) ? YAML::load(raw_yaml) : nil
      end
      _set_defaults_for_worker(config_hash)
      AppConfig.replace(config_hash)
      @load_hooks.each { |h| h.call(AppConfig) }
    rescue StandardError => ex
      msg = "#{ex.class}: #{ex.message}\n#{ex.backtrace.join("\n")}"
      if defined?(logger) && !logger.nil?
        logger.debug(msg)
      else
        $stderr.puts(msg)
      end
      raise NoConfiguration, "Failed to load configuration#{' from ' << file.expand_path unless arg.kind_of?(Hash)}"
    end
  end

  def config_path(config_name)
    @config_root+"data/#{config_name}/config/workgroup.yml"
  end

  def connections_path(config_name)
    @config_root+"data/#{config_name}/config/connections.yml"
  end

private
  # For each key starting with curent worker, eg, worker1.x.y.z = 1,
  # Place key in hash unqualified by worker, eg,  x.y.z = 1
  def _set_defaults_for_worker(config_hash)
    return unless config_hash.has_key?('worker_id')
    worker = "worker#{config_hash['worker_id']}"
    # Originally this updated config_hash in place in the for each loop, but that's not allowed in Ruby,
    # and once config_hash grew to a certain size, caused a "hash modified" error.
    # Thus using another hash instead and merging them.
    temp_hash = {}
    config_hash.each do |k, v|
      temp_hash[k[worker.size+1..-1]] = v  if k.index(worker) == 0
    end
    config_hash.merge!(temp_hash)
  end

  ## can be defined explicitly as java property, or derived as was done prior to jruby
  def _find_data_dir(dir)
    if java_prop = java.lang.System.get_property("wgserver.data_dir")
      if java_prop[-1,1] != '/'
        java_prop += '/'
      end
#       msg = "wgserver.data_dir defined as #{java_prop}"
#       if defined?(logger) && !logger.nil?
#         logger.debug(msg)
#       else
#         $stderr.puts(msg)
#       end
      java_prop
    else
      dir = Pathname.new(dir).expand_path
      if dir.basename.to_s == 'workgroup'
        # Development location
        dir
      else
        # Production location
        if (ENV['ProgramData'].nil? || ENV['ProgramData'].empty?)
          dir.dirname # Normally, just one level up
        else
          pd = Pathname.new(ENV['ProgramData']).expand_path
          pd = pd + 'Tableau/Tableau Server'
          progfiles = ENV['ProgramFiles'] || ""
          progfiles = Pathname.new(progfiles).expand_path.to_s.downcase # so path separators match
          vista_user_data_exists = File.exist?(pd + 'config/tabsvc.yml')
          installed_in_prog_files = !progfiles.empty? && dir.to_s.downcase.include?(progfiles)

          if ( installed_in_prog_files || vista_user_data_exists )
            # Vista dir exists AND (we're installed in Program Files, OR we don't have an existing
            # install we stuck there), so use the "C:\ProgramData" location as config root
            pd.mkpath
            pd
          else
            dir.dirname # Normally, just one level up
          end
        end
      end
    end
  end

  def _create_appconfig
    unless Object.const_defined?('AppConfig')
      Object.const_set('AppConfig', HierStruct.new)
    end
  end
end

AppConfigManager = AppConfigFactory.instance #unless Object.instance_eval("const_defined?('AppConfigManager')")

# Set the default tempdir for service apps
#
# $NOTE-jwhitley-2008-06-17: tabadmin employs SetTmp
# on its own, so don't load this hook in that case.
#
unless SetTmp.tmp_set?
  AppConfigManager.load_hooks << lambda do |config|
    SetTmp.tmpdir = config['service.temp.dir'] unless config['service.temp.dir'].nil?
  end
end
