
require 'time'
require 'httparty'
require 'nokogiri'
require 'forwardable'
require 'active_support/core_ext/object/blank'
require 'elibri_api_client/core_extensions'
require 'elibri_api_client/version'
require 'elibri_api_client/api_adapters'

module Elibri
  class ApiClient
    extend Forwardable

    DEFAULT_API_HOST_URI = 'http://api.elibri.com.pl:80'
    attr_reader :host_uri


    #  cli = Elibri::ApiClient.new(:login => '1b20fa9d72234423979c', :password => '2847cbf4f15a4057e2ab')
    #
    # Opcjonalnie mozna podac adres servera API:
    #  cli = Elibri::ApiClient.new(:host_uri => 'http://localhost:3010', :login => '1b20fa9d72234423979c', :password => '2847cbf4f15a4057e2ab')
    def initialize(options = {})
      @login = options[:login]
      @password = options[:password]
      @host_uri = options[:host_uri] || DEFAULT_API_HOST_URI

      # W przyszlosci moga byc nowe wersje API, wiec zostawiamy sobie furtke w postaci adapterow:
      api_version_str = options[:api_version] || 'v1'
      adapter_class = Elibri::ApiClient::ApiAdapters.const_get(api_version_str.upcase) # Elibri::ApiClient::ApiAdapters::V1
      @api_adapter = adapter_class.new(@host_uri, @login, @password)
    end


    # Metody API delegujemy do odpowiedniego adaptera:
    def_delegators :@api_adapter, :refill_all_queues!, :pending_data?, :pending_queues, :last_pickups, :publishers

  end
end
