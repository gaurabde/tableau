require 'fileutils'
require 'rubygems'




#  logging setup
class TabcmdLogger
  def info(arg)
    if defined?(Rails)
      Rails.logger.info(arg) if Rails.logger
    else
      puts(arg)
    end
  end

  alias :warn :info
  alias :debug :info
  alias :notice :info
  alias :infoing :info
  alias :error :info
end

unless Tabcmd::Test && (Object.respond_to? :logger)
  # Don't steal the global logger in test mode
  def logger
    TabcmdLogger.new
  end
end

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

unless Tabcmd::Test
  logger.debug "\n====================================================================="
  logger.debug "====>> Starting Tabcmd #{ProductVersion.current} at #{Time.now} <<===="
  logger.debug "Build #{ProductVersion.rstr}"
  at_exit do
    logger.debug "Finished at #{Time.now}"
  end
end # unless Tabcmd::Test
