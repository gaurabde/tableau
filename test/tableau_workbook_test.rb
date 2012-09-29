require 'tabcmd/tableau_workbook'
require 'minitest/autorun'
require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'fixtures/vcr_cassettes'
  c.hook_into :fakeweb
end

describe TableauWorkbook do
  it "sends an http request to Tableau for a table" do
    VCR.use_cassette('successful_create_table') do
      t = TableauWorkbook.new({
          :server => '10.80.129.167',
          :tableau_username => 'chorusadmin',
          :tableau_password => 'secret',
          :db_username => 'gpadmin',
          :db_password => 'secret',
          :db_host => 'chorus-gpdb42',
          :db_port => 5432,
          :db_database => 'ChorusAnalytics',
          :db_schema => 'public',
          :db_relname => 'TestGpfdists4',
          :name => 'new_workbook'
      })
      t.save.must_equal true
    end
  end

  it "sends an http request to Tableau for a chorus view" do
    VCR.use_cassette('successful_create_chorus_view') do
      t = TableauWorkbook.new({
                                  :server => '10.80.129.167',
                                  :tableau_username => 'chorusadmin',
                                  :tableau_password => 'secret',
                                  :db_username => 'gpadmin',
                                  :db_password => 'secret',
                                  :db_host => 'chorus-gpdb42',
                                  :db_port => 5432,
                                  :db_database => 'ChorusAnalytics',
                                  :db_schema => 'public',
                                  :query => 'SELECT 4;;',
                                  :name => 'workbook_chorus_view'
                              })
      res = t.save
      p t.errors
      res.must_equal true

    end
  end

  it "strips the trailing semi-colon for a chorus view" do
    TableauWorkbook.strip_trailing_semicolon("select 1;;;;").must_equal "select 1"
    TableauWorkbook.strip_trailing_semicolon("select 1").must_equal "select 1"
  end

  it "fails when the server does not exist giving an error" do
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