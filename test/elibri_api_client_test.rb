require 'helper'


# Testowy adapter
module Elibri
  class ApiClient
    module ApiAdapters
      # Testowy adapter.
      class V999
        def initialize(host_uri, login, password, onix_dialect)
        end
      end
    end
  end
end


describe Elibri::ApiClient do

  it "should be able to establish its version" do
    assert_match /\d+\.\d+\.\d+/, Elibri::ApiClient::VERSION
    assert_match /\d+\.\d+\.\d+/, Elibri::ApiClient::Version
  end


  it "should take some defaults in constructor" do
    client = Elibri::ApiClient.new(:login => 'elibri_login', :password => 'pass', :onix_dialect => '3.0.1')
    assert_equal Elibri::ApiClient::DEFAULT_API_HOST_URI, client.host_uri

    client = Elibri::ApiClient.new(:login => 'elibri_login', :password => 'pass', :host_uri => 'http://localhost:3000', :onix_dialect => '3.0.1')
    assert_equal 'http://localhost:3000', client.host_uri
  end


  it "should force user to specify ONIX dialect" do
    assert_raises RuntimeError do
      Elibri::ApiClient.new(:login => 'elibri_login', :password => 'pass')
    end
  end


  it "should enable user to pick a version of API" do
    client = Elibri::ApiClient.new(:login => 'elibri_login', :password => 'pass', :api_version => 'v999', :onix_dialect => '3.0.1')
    assert_kind_of Elibri::ApiClient::ApiAdapters::V999, client.instance_variable_get('@api_adapter')
  end
  
  
  it "should delegate several methods to apropriate API adapter" do
    client = Elibri::ApiClient.new(:login => 'elibri_login', :password => 'pass', :onix_dialect => '3.0.1')

    delegated_methods = %w{refill_all_queues! pending_data? pending_queues publishers}
    delegated_methods.each {|method_name| client.instance_variable_get('@api_adapter').expects(method_name) }
    delegated_methods.each {|method_name| client.send(method_name) }
  end
  

end

