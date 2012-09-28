require_relative './tabcmd_gem'
require 'optparse'

class TableauWorkbook
  def initialize(hsh)
    @server = hsh[:server]

    @errors = []
  end

  def errors
    @errors
  end

  def save
    publish = MultiCommand::CommandManager.find_command('publish')

    opts = OptionParser.new
    argv = ['-o',
            '-s' , "http://#{@server}",
            '--username', 'chorusadmin',
            '--password', 'secret',
            '--db-username', 'gpadmin',
            '--db-password', 'secret',
            '--name', "new_workbook"]

    MultiCommand::CommandManager.define_options(opts, argv)
    publish.define_options(opts, argv)
    opts.parse!(argv)

    temp = Tempfile.new(['tableau_workbook', '.twb'])
    temp.puts File.read(File.expand_path(File.dirname(__FILE__) + '/example.twb.erb'))

    begin
      publish.run(opts, [temp.path])
      true
    rescue Exception => e
      errors << e.message
      false
    end
  end
end