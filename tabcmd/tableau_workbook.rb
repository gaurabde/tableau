require_relative './tabcmd_gem'
require 'optparse'
require 'erb'

class TableauWorkbook
  def initialize(hsh)
    @server = hsh[:server]
    @tableau_username = hsh[:tableau_username]
    @tableau_password = hsh[:tableau_password]
    @db_username = hsh[:db_username]
    @db_password = hsh[:db_password]
    @db_host = hsh[:db_host]
    @db_port = hsh[:db_port]
    @db_database = hsh[:db_database]
    @db_schema = hsh[:db_schema]
    @db_relname = hsh[:db_relname]
    @query = TableauWorkbook.strip_trailing_semicolon(hsh[:query]) if hsh[:query]
    @name = hsh[:name]
    @errors = []
  end

  def errors
    @errors
  end

  def is_chorus_view?
    @query.present?
  end

  def self.strip_trailing_semicolon(str)
    return str.sub(/;+$/, '')
  end

  def save
    publish = MultiCommand::CommandManager.find_command('publish')

    opts = OptionParser.new
    argv = ['-o',
            '-s' , "http://#{@server}",
            '--username', @tableau_username,
            '--password', @tableau_password,
            '--db-username', @db_username,
            '--db-password', @db_password,
            '--name', @name]

    MultiCommand::CommandManager.define_options(opts, argv)
    publish.define_options(opts, argv)
    opts.parse!(argv)

    temp = Tempfile.new(['tableau_workbook', '.twb'])
    template = ERB.new(File.read(File.expand_path(File.dirname(__FILE__) + '/example.twb.erb')))
    s = template.result(binding)
    temp.puts s

    begin
      publish.run(opts, [temp.path])
      true
    rescue Exception => e
      errors << e.message
      false
    end
  end
end