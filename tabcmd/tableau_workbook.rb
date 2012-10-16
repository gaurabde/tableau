require_relative './tabcmd_gem'
require 'optparse'
require 'erb'
require 'active_model'
require 'nokogiri'

class TableauWorkbook
  include ActiveModel::Validations

  validates_presence_of :name
  validates_length_of :name, :minimum => 1, :maximum => 64

  attr_accessor :name

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

    publish.run(opts, [temp.path])
    true
  rescue MultiCommand::ExitWithStatus
    errors.add(:tableau, "Could not publish Tableau workbook. Ensure that the database #{@db_host}:#{@db_port} is reachable from the Tableau server.")
    false
  rescue Exception => e
    errors.add(:tableau, e.message)
    false
  end

  def image_url

    t = Tempfile.new('workbook_xml')
    get = MultiCommand::CommandManager.find_command('get')
    opts = OptionParser.new
    argv = ['-s', "http://#{@server}",
           '--username', @tableau_username,
           '--password', @tableau_password,
           '-f', t.path]
    MultiCommand::CommandManager.define_options(opts, argv)
    get.define_options(opts, argv)
    opts.parse!(argv)
    get.run(opts, ["workbooks/#{name}.xml"])
    doc = Nokogiri::XML.parse(t.read)
    view_name = doc.search('view').first.search('name').text.gsub(/\s+/, '')
    return "http://#{@server}/views/#{name}/#{view_name}.png"
  end
end