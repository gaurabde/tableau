require 'tabcmd/tableau_workbook'
gem 'minitest'
require 'minitest/autorun'
require 'vcr'

TABLEAU_SERVER_IP='10.80.129.44'

VCR.configure do |c|
  c.cassette_library_dir = 'fixtures/vcr_cassettes'
  c.hook_into :fakeweb
end

describe TableauWorkbook do
  describe 'validations' do
    before do
      @valid_params = {
          :server => TABLEAU_SERVER_IP,
          :tableau_username => 'chorusadmin',
          :tableau_password => 'secret',
          :db_username => 'gpadmin',
          :db_password => 'secret',
          :db_host => 'chorus-gpdb42',
          :db_port => 5432,
          :db_database => 'ChorusAnalytics',
          :db_schema => 'public',
          :db_relname => 'TestGpfdists4'}
    end

    it 'validates presence of name' do
      @valid_params.delete(:name)
      t = TableauWorkbook.new(@valid_params)
      t.valid?.must_equal false
    end

    it 'validates length of name' do
      t = TableauWorkbook.new(@valid_params.merge!(:name => 65.times.collect{'a'}.join("")))
      t.valid?.must_equal false
    end
  end

  it "sends an http request to Tableau for a table" do
    VCR.use_cassette('successful_create_table') do
      t = TableauWorkbook.new({
          :server => TABLEAU_SERVER_IP,
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
                                  :server => TABLEAU_SERVER_IP,
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
      t.errors.full_messages[0].must_match /bad URI/
    end
  end

  it "does not crash if missing options" do
    VCR.use_cassette('create_missing_options') do
      t = TableauWorkbook.new({
                                  :server => '',
                                  :tableau_username => '',
                                  :tableau_password => '',
                                  :db_username => '',
                                  :db_password => '',
                                  :db_host => '',
                                  :db_port => 5432,
                                  :db_database => '',
                                  :db_schema => '',
                                  :db_relname => '',
                                  :name => 'new_'
                              })
      t.save.must_equal false
      t.errors.empty?.must_equal false
      t.errors.full_messages[0].must_match /bad URI/
    end
  end

  it "gets the first full size image view for a tableau workbook" do
    VCR.use_cassette('get_full_size_image') do
      t = TableauWorkbook.new({:name => 'BusinessDashboard',
                               :server => TABLEAU_SERVER_IP,
                               :tableau_username => 'chorusadmin',
                               :tableau_password => 'secret'})
      t.image_url
      t.image_url.must_equal "http://#{TABLEAU_SERVER_IP}/views/BusinessDashboard/AreaSalesPerformance.png"
    end
  end
end
