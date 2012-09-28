require 'tabcmd/tableau_workbook'
require 'minitest/autorun'
require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'fixtures/vcr_cassettes'
  c.hook_into :fakeweb
end

describe TableauWorkbook do
  it "can create a new workbook from a database relation" do
    # instance host, port, username, password, database, schema, relation name, workbook name
    TableauWorkbook.new()
  end

  it "can create a new workbook from a SQL query" do
    # instance host, port, username, password, database, schema, query, workbook name
    TableauWorkbook.new()
  end

  it "sends an http request to Tableau" do
    VCR.use_cassette('successful_create') do
      require 'tabcmd/tabcmd_gem'
      require 'optparse'

      publish = MultiCommand::CommandManager.find_command('publish')

      opts = OptionParser.new
      argv = ['-o',
              '-s' ,'http://10.80.129.167',
              '--username', 'chorusadmin',
              '--password', 'secret',
              '--db-username', 'gpadmin',
              '--db-password', 'secret',
              '--name', "new_workbook"]

      MultiCommand::CommandManager.define_options(opts, argv)
      publish.define_options(opts, argv)
      opts.parse!(argv)

      filepath = File.expand_path(__FILE__ + '/../example.twb')
      publish.run(opts, [filepath])
    end
  end

end