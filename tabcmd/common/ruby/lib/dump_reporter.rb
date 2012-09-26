require 'tabutil'

class DumpReporter
  def initialize(app_name, log_dir, exit_on_exception)
    Tabutil::Tabutil.setup_fault_reporting(log_dir.to_s.gsub('/', '\\'),
                                           app_name, true, exit_on_exception)
    ObjectSpace.define_finalizer(self, lambda { Tabutil.destroy_fault_reporting })
  end

  def self.setup(app_name, log_dir, exit_on_exception)
    $dump_reporter = DumpReporter.new(app_name, log_dir, exit_on_exception)
  end
  
  def self.force_crash
    Tabutil.force_fault
  end
end
