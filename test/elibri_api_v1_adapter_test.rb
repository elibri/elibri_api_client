#encoding: UTF-8
require 'helper'


describe Elibri::ApiClient::ApiAdapters::V1 do

  FAKE_API_HOST = 'http://localhost:5000'

  def get_request_expected(request_uri, options = {})
    Elibri::ApiClient::ApiAdapters::V1.expects(:get).with(
      request_uri,
      {:digest_auth => {:username => 'login', :password => 'password'}}.merge(options)
    )
  end


  def post_request_expected(request_uri, options = {})
    options[:body] = ' ' unless options[:body]

    Elibri::ApiClient::ApiAdapters::V1.expects(:post).with(
      request_uri,
      {:digest_auth => {:username => 'login', :password => 'password'}}.merge(options)
    )
  end


  before do
    @adapter = Elibri::ApiClient::ApiAdapters::V1.new(FAKE_API_HOST, 'login', 'password', '3.0.1')
  end


  it "should define several exception classes" do
    exception_classes = %w{NotFound Forbidden ServerError InvalidLoginOrPassword QueueDoesNotExists NoRecentlyPoppedData InvalidOnixDialect}
    exception_classes.each do |exception_class|
      assert(Elibri::ApiClient::ApiAdapters::V1::Exceptions.const_get(exception_class) < RuntimeError)
    end  
  end
  

  it "should be able to refill all pending queues" do
    response_stub = stub('response_stub', :code => 200, :parsed_response => nil)
    post_request_expected("#{FAKE_API_HOST}/api/v1/queues/refill_all").returns(response_stub)
    @adapter.refill_all_queues!
  end


  it "should normalise request URI before performing real request" do
    response_stub = stub('response_stub', :code => 200, :parsed_response => nil)

    get_request_expected("#{FAKE_API_HOST}/api/v1/api_entrypoint").once.returns(response_stub)
    @adapter.send(:get, "#{FAKE_API_HOST}/api/v1/api_entrypoint")

    get_request_expected("#{FAKE_API_HOST}/api/v1/api_entrypoint?param1=value1").once.returns(response_stub)
    @adapter.send(:get, '/api_entrypoint?param1=value1')

    get_request_expected("#{FAKE_API_HOST}/api/v1/api_entrypoint_without_leading_slash").once.returns(response_stub)
    @adapter.send(:get, 'api_entrypoint_without_leading_slash')
  end
  
  

  describe "when asked to establish pending queues list" do

    describe "and there is pending data awaiting for pop" do
      before do
        xml = <<-XML
          <queues>
            <queue name="meta" products_count="24" last_insert_at="2011-02-05 21:02:22 UTC"/>      
            <queue name="stocks" products_count="1500" last_insert_at="2011-02-05 21:02:22 UTC"/>         
          </queues>
        XML

        response_stub = stub('response_stub', :code => 200, :parsed_response => Nokogiri::XML(xml))
        get_request_expected("#{FAKE_API_HOST}/api/v1/queues").at_least_once.returns(response_stub)
      end


      it "should return Queue instances with attributes filled from returned XML" do
        assert @adapter.pending_data?
        pending_queues = @adapter.pending_queues
        assert_equal 2, pending_queues.size

        meta = pending_queues.find {|queue| queue.name == 'meta' }
        stocks = pending_queues.find {|queue| queue.name == 'stocks' }

        assert_equal 24, meta.products_count
        assert_kind_of Time, meta.last_insert_at 

        assert_equal 1500, stocks.products_count
        assert_kind_of Time, stocks.last_insert_at 
      end
    end


    describe "and there is no pending data awaiting for pull" do
      before do
        xml = <<-XML
          <queues>
            <queue name="meta" products_count="0" />      
            <queue name="stocks" products_count="0" />         
          </queues>
        XML

        response_stub = stub('response_stub', :code => 200, :parsed_response => Nokogiri::XML(xml))
        get_request_expected("#{FAKE_API_HOST}/api/v1/queues").at_least_once.returns(response_stub)
      end


      it "should return empty array and claim that there is no pending data" do
        assert @adapter.pending_queues.empty?
        assert !@adapter.pending_data?
      end
    end
  end
  

  describe "when there was error reported" do
    before do
      @xml = %q{<error id="ERROR_CODE"> <message>Error message for error ERROR_CODE</message> </error>}
      @exception_classes = {
        '404' =>  Elibri::ApiClient::ApiAdapters::V1::Exceptions::NotFound,
        '403' =>  Elibri::ApiClient::ApiAdapters::V1::Exceptions::Forbidden,
        '500' =>  Elibri::ApiClient::ApiAdapters::V1::Exceptions::ServerError,
        '1000' => Elibri::ApiClient::ApiAdapters::V1::Exceptions::InvalidLoginOrPassword,
        '1001' => Elibri::ApiClient::ApiAdapters::V1::Exceptions::QueueDoesNotExists,
        '1002' => Elibri::ApiClient::ApiAdapters::V1::Exceptions::NoRecentlyPoppedData,
        '1003' => Elibri::ApiClient::ApiAdapters::V1::Exceptions::InvalidOnixDialect,
      }
    end


    it "should raise proper exception class" do
      @exception_classes.each do |error_code, exception_class|
        response_stub = stub('response_stub', :code => 200, :parsed_response => Nokogiri::XML( @xml.gsub('ERROR_CODE', error_code) ))
        get_request_expected("#{FAKE_API_HOST}/api/v1/queues").once.returns(response_stub)
        assert_raises(exception_class) { @adapter.pending_queues }
      end  
    end


    it "should raise InvalidLoginOrPassword, when there is 401 response code" do
      parsed_response = Nokogiri::XML(<<-XML)
        <error id="1000">
          <message>Invalid login or password</message>
        </error>
      XML
      response_stub = stub('response_stub', :code => 401, :parsed_response => parsed_response)
      get_request_expected("#{FAKE_API_HOST}/api/v1/queues").once.returns(response_stub)
      assert_raises(Elibri::ApiClient::ApiAdapters::V1::Exceptions::InvalidLoginOrPassword) { @adapter.pending_queues }
    end


    it "should raise RuntimeError on unknown error code" do
      response_stub = stub('response_stub', :code => 200, :parsed_response => Nokogiri::XML( @xml.gsub('ERROR_CODE', 'UNKNOWN_ERROR_CODE') ))
      get_request_expected("#{FAKE_API_HOST}/api/v1/queues").once.returns(response_stub)
      assert_raises(Elibri::ApiClient::ApiAdapters::V1::Exceptions::UnknownError) { @adapter.pending_queues }
    end
    
  end


  describe "when asked to establish available publishers list" do
    before do
      xml = <<-XML
        <publishers>
          <publisher name="Wydawnicta Naukowo-Techniczne" city="Kraków" company_name="WNT Polska Sp. z o.o." zip_code="30-417" id="1" street="Łagiewnicka 33a" phone1="(12) 252-85-92" phone2="(12) 252-85-80" nip="679-284-08-64" www="http://www.wnt.com" email="sprzedaz@wnt.com">
            <products url="#{FAKE_API_HOST}/api/v1/publishers/1/products" count="350"/>
          </publisher>
          <publisher name="Abiekt.pl" city="Warszawa" www="http://www.abiekt.pl" company_name="Abiekt.pl Sp&#243;&#322;ka z o.o." zip_code="00-785" id="2" street="Grottgera 9a/7" phone1="609-626-500" nip="521-348-37-69" email="wojciech.szot@abiekt.pl">
            <products url="#{FAKE_API_HOST}/api/v1/publishers/2/products" count="7"/>
          </publisher>
        </publishers>
      XML
      response_stub = stub('response_stub', :code => 200, :parsed_response => Nokogiri::XML(xml))
      get_request_expected("#{FAKE_API_HOST}/api/v1/publishers").at_least_once.returns(response_stub)
    end


    it "should return Publisher instances with attributes filled from returned XML" do
      publishers = @adapter.publishers
      assert_equal 2, publishers.size
      assert(publishers.all? { |publisher| publisher.kind_of? Elibri::ApiClient::ApiAdapters::V1::Publisher })

      wnt = publishers.find {|publisher| publisher.publisher_id == 1}
      abiekt = publishers.find {|publisher| publisher.publisher_id == 2}

      # Wyrywkowo sprawdzamy atrybuty:
      assert_equal 350, wnt.products_count
      assert_equal 7, abiekt.products_count
      assert_equal "521-348-37-69", abiekt.nip
      assert_equal "Łagiewnicka 33a", wnt.street
    end
  end



  describe "when asked to get products list for specified publisher" do
    before do
      @publisher = Elibri::ApiClient::ApiAdapters::V1::Publisher.new(@adapter, :publisher_id => 1234)
      xml = <<-XML
        <publisher id="#{@publisher.publisher_id}" name="Wydawnicta Naukowo-Techniczne">
          <products count="3" url="#{FAKE_API_HOST}/api/v1/publishers/#{@publisher.publisher_id}/products">
            <product title="Erlang Programming" record_reference="04325b31fdece145d22e" url="#{FAKE_API_HOST}/api/v1/products/04325b31fdece145d22e"/>
            <product title="The Little Schemer" record_reference="993140a24d8202a347cc" url="#{FAKE_API_HOST}/api/v1/products/993140a24d8202a347cc"/>
            <product title="The Rails Way" record_reference="a40f41cf67facf1876e3" url="#{FAKE_API_HOST}/api/v1/products/a40f41cf67facf1876e3"/>
          </products>
        </publisher>
      XML
      response_stub = stub('response_stub', :code => 200, :parsed_response => Nokogiri::XML(xml))
      get_request_expected("#{FAKE_API_HOST}/api/v1/publishers/1234/products").at_least_once.returns(response_stub)
    end


    it "should return Product instances with attributes filled from returned XML" do
      products = @adapter.products_for_publisher(@publisher)
      assert_equal 3, products.size
      assert(products.all? { |product| product.kind_of? Elibri::ApiClient::ApiAdapters::V1::Product })

      erlang_programming = products.find {|product| product.record_reference == '04325b31fdece145d22e'}
      assert_equal 'Erlang Programming', erlang_programming.title
      assert_equal '04325b31fdece145d22e', erlang_programming.record_reference
      assert_equal "#{FAKE_API_HOST}/api/v1/products/04325b31fdece145d22e", erlang_programming.url
    end
  end


  describe "when asked to product ONIX XML for specified product" do
    before do
      @product = Elibri::ApiClient::ApiAdapters::V1::Product.new(@adapter, stub('publisher'), :record_reference => '076eb83a5f01cb03a217')
      xml = %Q{<Product><RecordReference>076eb83a5f01cb03a217</RecordReference></Product>}
      response_stub = stub('response_stub', :code => 200, :parsed_response => Nokogiri::XML(xml))
      get_request_expected("#{FAKE_API_HOST}/api/v1/products/076eb83a5f01cb03a217", :headers => {'X-eLibri-API-ONIX-dialect' => '3.0.1'}).at_least_once.returns(response_stub)
    end


    it "should return parsed ONIX XML" do
      product_xml = @adapter.onix_xml_for_product(@product)
      assert_kind_of Nokogiri::XML::Element, product_xml
      assert_equal '076eb83a5f01cb03a217', product_xml.css('RecordReference').text
    end

  end



  describe "when asked to pop data from specified queue name" do

    before do
      @xml = <<-XML
        <?xml version="1.0" encoding="UTF-8"?>
        <ONIXMessage release="3.0" xmlns:elibri="http://elibri.com.pl/ns/extensions" xmlns="http://www.editeur.org/onix/3.0/reference">
          <elibri:Dialect>3.0.1</elibri:Dialect>
          <Header>
            <Sender>
              <SenderName>Elibri.com.pl</SenderName>
              <ContactName>Tomasz Meka</ContactName>
              <EmailAddress>kontakt@elibri.com.pl</EmailAddress>
            </Sender>
            <SentDateTime>20111009</SentDateTime>
          </Header>
          <Product>
            <RecordReference>fdb8fa072be774d97a97</RecordReference>
            <NotificationType>01</NotificationType>
          </Product>
          <Product>
            <RecordReference>6de1bed2f70a8cdae200</RecordReference>
            <NotificationType>01</NotificationType>
          </Product>
        </ONIXMessage>
      XML
    end


    it "should send params when they are specified and return QueuePop instance" do
      @response_stub = stub('response_stub',
        :code => 200,
        :body => @xml,
        :parsed_response => Nokogiri::XML(@xml),
        :headers => {"x-elibri-api-pop-products-count" => 2, "x-elibri-api-pop-queue-name" => "meta", "x-elibri-api-pop-created-at" => "2011-09-06 13:58:21 UTC"}
      )

      post_request_expected(
        "#{FAKE_API_HOST}/api/v1/queues/meta/pop",
        :body => {:testing => 1, :count => 5},
        :headers => {'X-eLibri-API-ONIX-dialect' => '3.0.1'}
      ).at_least_once.returns(@response_stub)

      pop = @adapter.pop_from_queue('meta', :testing => true, :count => 5)
      assert_kind_of Elibri::ApiClient::ApiAdapters::V1::QueuePop, pop
      assert_equal 2, pop.popped_products_count
      assert_equal 'fdb8fa072be774d97a97', pop.onix.products.first.record_reference
    end


    it "should send empty request body when no params are specified" do
      @response_stub = stub('response_stub',
        :code => 200,
        :body => @xml,
        :parsed_response => Nokogiri::XML(@xml),
        :headers => {"x-elibri-api-pop-products-count" => 2, "x-elibri-api-pop-queue-name" => "meta", "x-elibri-api-pop-created-at" => "2011-09-06 13:58:21 UTC"}
      )

      post_request_expected(
        "#{FAKE_API_HOST}/api/v1/queues/meta/pop",
        :body => ' ',
        :headers => {'X-eLibri-API-ONIX-dialect' => '3.0.1'}
      ).at_least_once.returns(@response_stub)

      pop = @adapter.pop_from_queue('meta')
      assert_kind_of Elibri::ApiClient::ApiAdapters::V1::QueuePop, pop
      assert_equal 2, pop.popped_products_count
    end


    it "should return nil when there is no data to pop" do
      @response_stub = stub('response_stub',
        :code => 200,
        :body => nil,
        :parsed_response => nil,
        :headers => {"x-elibri-api-pop-products-count" => 0}
      )

      post_request_expected(
        "#{FAKE_API_HOST}/api/v1/queues/meta/pop",
        :body => ' ',
        :headers => {'X-eLibri-API-ONIX-dialect' => '3.0.1'}
      ).at_least_once.returns(@response_stub)

      assert_nil @adapter.pop_from_queue('meta')
    end

  end


  describe "when asked to get last pop for specified queue name" do

    describe "and there was no recent pop" do
      before do
        xml = %q{<error id='1002'> <message>There is no recently popped data</message> </error>}
        response_stub = stub('response_stub', :code => 412, :parsed_response => Nokogiri::XML(xml))
        get_request_expected("#{FAKE_API_HOST}/api/v1/queues/meta/last_pop", :headers => {'X-eLibri-API-ONIX-dialect' => '3.0.1'}).once.returns(response_stub)
      end

      it "should return nil, ignoring NoRecentlyPoppedData exception" do
        assert_nil @adapter.last_pop_from_queue('meta')
      end
    end


    describe "and there was a pop" do

      before do
        @xml = <<-XML
          <?xml version="1.0" encoding="UTF-8"?>
          <ONIXMessage release="3.0" xmlns:elibri="http://elibri.com.pl/ns/extensions" xmlns="http://www.editeur.org/onix/3.0/reference">
            <elibri:Dialect>3.0.1</elibri:Dialect>
            <Header>
              <Sender>
                <SenderName>Elibri.com.pl</SenderName>
                <ContactName>Tomasz Meka</ContactName>
                <EmailAddress>kontakt@elibri.com.pl</EmailAddress>
              </Sender>
              <SentDateTime>20111009</SentDateTime>
            </Header>
            <Product>
              <RecordReference>fdb8fa072be774d97a97</RecordReference>
              <NotificationType>01</NotificationType>
            </Product>
            <Product>
              <RecordReference>6de1bed2f70a8cdae200</RecordReference>
              <NotificationType>01</NotificationType>
            </Product>
          </ONIXMessage>
        XML
      end


      it "should return QueuePop instance" do
        response_stub = stub('response_stub',
          :code => 200,
          :body => @xml,
          :parsed_response => Nokogiri::XML(@xml),
          :headers => {"x-elibri-api-pop-products-count" => 2, "x-elibri-api-pop-queue-name" => "meta", "x-elibri-api-pop-created-at" => "2011-09-06 13:58:21 UTC"}
        )
        get_request_expected("#{FAKE_API_HOST}/api/v1/queues/meta/last_pop", :headers => {'X-eLibri-API-ONIX-dialect' => '3.0.1'}).at_least_once.returns(response_stub)

        pop = @adapter.last_pop_from_queue('meta')
        assert_kind_of Elibri::ApiClient::ApiAdapters::V1::QueuePop, pop
        assert_equal 2, pop.popped_products_count
        assert_equal 'fdb8fa072be774d97a97', pop.onix.products.first.record_reference
      end
    end


  end


end
