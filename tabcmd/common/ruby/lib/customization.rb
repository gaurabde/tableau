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
require 'singleton'
require 'yaml'

class AppCustomizationFactory
  include Singleton

  def initialize
    _create_customization
    explicit_root_dir = java.lang.System.get_property("tableau.jar.root")
    if explicit_root_dir
      # if the incoming string is wrapped in single-quotes (bat-file horribleness), strip them
      explicit_root_dir = explicit_root_dir.gsub(/^'/,'').gsub(/'$/,'')
      @root_dir = Pathname.new(File.expand_path(explicit_root_dir + '/..'))
    else
      @root_dir = Pathname.new(File.expand_path(File.dirname(__FILE__)+'/../../..'))
    end
    self.config_root = @root_dir
  end

  attr_reader :config_root, :root_dir

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

  def load_by_name(config_name)
    load(config_path(config_name))
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
      AppCustomization.replace(config_hash)
    rescue Exception => ex
      raise NoConfiguration, "Failed to load configuration#{' from ' << file.expand_path unless arg.kind_of?(Hash)} (#{ex.inspect})"
    end
  end

  def config_path(config_name)
    @config_root+"data/#{config_name}/config/customization.yml"
  end

  private
  def _find_data_dir(dir)
    if java_prop = java.lang.System.get_property("wgserver.data_dir")
      if java_prop[-1,1] != '/'
        java_prop += '/'
      end
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

  def _create_customization
    unless Object.const_defined?('AppCustomization')
      Object.const_set('AppCustomization', HierStruct.new)
    end
  end
end

AppCustomizationManager = AppCustomizationFactory.instance
