require 'tabcmd/tableau_workbook'
require 'minitest/autorun'
require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'fixtures/vcr_cassettes'
  c.hook_into :fakeweb
end

describe TableauWorkbook do
  #it "can create a new workbook from a SQL query" do
  #  # instance host, port, username, password, database, schema, query, workbook name
  #  TableauWorkbook.new({})
  #end

  it "sends an http request to Tableau" do
    VCR.use_cassette('successful_create') do
      t = TableauWorkbook.new({
          :server => '10.80.129.167',
          :tableau_username => 'chorusadmin',
          :tableau_password => 'secret',
          :db_username => 'gpadmin',
          :db_password => 'secret',
          :db_host => 'abc',
          :db_port => 5432,
          :db_database => 'ChorusAnalytics',
          :db_schema => 'abc',
          :db_relname => 'tablename',
          :name => 'new_workbook'
      })
      t.save.must_equal true
    end
  end

  it "sends an http request to Tableau" do
    VCR.use_cassette('failed_create') do
      t = TableauWorkbook.new({
                                  :server => '',
                                  :tableau_username => 'chorusadmin',
                                  :tableau_password => 'secret',
                                  :db_username => 'gpadmin',
                                  :db_password => 'secret',
                                  :db_host => 'abc',
                                  :db_port => 5432,
                                  :db_database => 'ChorusAnalytics',
                                  :db_schema => 'abc',
                                  :db_relname => 'tablename',
                                  :name => 'new_workbook'
                              })
      t.save.must_equal false
      t.errors.empty?.must_equal false
      t.errors[0].must_match /bad URI/
    end
  end
end