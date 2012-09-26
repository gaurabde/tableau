# -----------------------------------------------------------------------
# The information in this file is the property of Tableau Software and
# is confidential.
#
# Copyright (C) 2005-2008    Tableau Software.
# Patents Pending.
# -----------------------------------------------------------------------

# Configure Log4r

require 'rubygems'
require 'log4r'
require 'log4r/configurator'

include Log4r


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

  ## ignore incoming level (passed in as method) and log at 'fatal' to ensure notify-logs and normal logs both see it.
  def self.log_exception(exc, logger, method, msg = "")
    unless exc.nil? || (exc.respond_to?(:already_logged?) && exc.already_logged?) || logger.nil? || method.nil?
      if exc.is_a?(ReportableError)
        logger.send(:fatal, %Q[#{msg + "\n" unless (msg.nil? || msg.empty?)}#{exc.class.name}: #{exc}])
      else
        logger.send(:fatal, %Q[#{msg + "\n" unless (msg.nil? || msg.empty?)}#{exc.class.name}: #{exc}\n#{(exc.backtrace || []).join("\n")}])
      end
      exc.mark_logged! if exc.respond_to?(:mark_logged!)
    end
  end

end

# rolling log file config. either the code that included this file already set
# this var, or its value is set to "0" so that it's shut-off.
$log_max_time ||= "0"

Configurator["log_file"] = $log_path
Configurator["notify_log_file"] = $notify_log_path
Configurator["log_level"] = $log_level || 'OFF'
Configurator["log_max_time"] = $log_max_time.to_s
Configurator["application_name"] = "Tableau Server"
Configurator["log_pattern"] = '%d_level=%l_server=%x{:local_ip}:%x{:local_hostname}_service=%g:%x{:worker_id}_pid=%x{:process_pid}_tid=%x{:thread_id}_user=%x{:user_id}_session=%x{:session_id}_request=%x{:originating}_context=%y_message=%m'


allowed_outputters = "all_file_log,nt_event_log,notify_file_log"
if defined?(Rails)
  if Rails.env.test?
    allowed_outputters = "all_file_log"
  end
end
Configurator["allowed_outputters"] = allowed_outputters
