class DumpReporter
  def initialize(app_name, log_dir, exit_on_exception)
  end

  def self.setup(app_name, log_dir, exit_on_exception)
    $dump_reporter = DumpReporter.new(app_name, log_dir, exit_on_exception)
  end

  def self.force_crash
  end
end
