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

# Configure Log4r

require 'fileutils'
require 'rubygems'
require 'log4r'
require 'log4r/configurator'

module Log4r
  class Logger
    def disable
      saved_outputters = @outputters.dup
      @outputters.clear
      begin
        yield
      ensure
        @outputters = saved_outputters
      end
    end
  end
end

Log4r::Configurator.custom_levels(*%w{DEBUG NOTICE INFO WARN ERROR FATAL})
Log4r::Logger.root.level = Log4r::ALL


#  logging setup
TabcmdLogger = Log4r::Logger.new 'Tabcmd'

unless Tabcmd::Test && (Object.respond_to? :logger)
  # Don't steal the global logger in test mode
  def logger
    TabcmdLogger
  end
end

# These outputters are used for console formatting...
p_info   = Log4r::PatternFormatter.new(:pattern =>"===== %m")
p_notice = Log4r::PatternFormatter.new(:pattern =>"   -- %m")
p_warn   = Log4r::PatternFormatter.new(:pattern =>"  *** %m")
# ... and this one formats to the log file
p_file = Log4r::PatternFormatter.new(:pattern => %(#{"[%-4d]" % Process.pid} %-6l %d: %m), :date_pattern => "%b-%d %H:%M:%S")

outputters = []

unless Tabcmd::Test
  outputters << Log4r::StdoutOutputter.new('stdout', :level => Log4r::INFO, :formatter => p_info)
  outputters.last.only_at Log4r::INFO
  outputters << Log4r::StdoutOutputter.new('stdout', :level => Log4r::NOTICE, :formatter => p_notice)
  outputters.last.only_at Log4r::NOTICE
  outputters << Log4r::StderrOutputter.new('stderr', :level => Log4r::WARN, :formatter => p_warn)
end

TabcmdLogger.add(*outputters)

include FileUtils::Verbose

unless Tabcmd::Test
  # redirect FileUtils output to the logger
  # Doing this before creating the log directory ensures that FileUtils's
  # echoing of "mkdir_p <directory name> gets swallowed.
  module FileUtils
    def fu_output_message(msg)
      logger.debug(msg)
    end
  end
end

if ENV['APPDATA']
  log_dir =   Pathname.new(File.join(ENV['APPDATA'], 'Tableau'))
  local_log_file = File.expand_path('tabcmd.log', log_dir)

  # Make sure the log directory exists before instantiating the 
  # file outputter
  mkdir_p(log_dir) unless log_dir.directory?

  require 'dump_reporter'
  DumpReporter.setup("tabcmd", log_dir, false)

  begin
    TabcmdLogger.add  Log4r::FileOutputter.new('rake.log',
                                               :filename => local_log_file,
                                               :level => Log4r::ALL,
                                               :formatter => p_file,
                                               :trunc => false)
  rescue Errno::EACCES
    # fail gracefully if we can't write to our log file.
    TabcmdLogger.warn "Unable to write to log file: #{local_log_file}.  Continuing without file logging."
  end
else
  TabcmdLogger.warn "APPDATA environment variable is not set.  Continuing without file logging."
end

unless Tabcmd::Test
  logger.debug "\n====================================================================="
  logger.debug "====>> Starting Tabcmd #{ProductVersion.current} at #{Time.now} <<===="
  logger.debug "Build #{ProductVersion.rstr}"
  at_exit do
    logger.debug "Finished at #{Time.now}"
  end
end # unless Tabcmd::Test
