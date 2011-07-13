require 'helper'


describe Elibri::ApiClient::ApiAdapters::V1 do

  FAKE_API_HOST = 'http://localhost:5000'

  def get_request_expected(request_uri)
    Elibri::ApiClient::ApiAdapters::V1.expects(:get).with(
      request_uri,
      {:digest_auth => {:username => 'login', :password => 'password'}}
    )
  end


  def post_request_expected(request_uri)
    Elibri::ApiClient::ApiAdapters::V1.expects(:post).with(
      request_uri,
      {:body => ' ', :digest_auth => {:username => 'login', :password => 'password'}}
    )
  end


  before do
    @adapter = Elibri::ApiClient::ApiAdapters::V1.new(FAKE_API_HOST, 'login', 'password')
  end


  it "should define several exception classes" do
    exception_classes = %w{Unauthorized NotFound Forbidden ServerError NoPendingData NoRecentlyPickedUpQueues QueueDoesNotExists InvalidPageNumber}
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

    get_request_expected("#{FAKE_API_HOST}/api/v1/queues/meta/192f134e666df34464bcc14d0413").once.returns(response_stub)
    @adapter.send(:get, "#{FAKE_API_HOST}/api/v1/queues/meta/192f134e666df34464bcc14d0413")

    get_request_expected("#{FAKE_API_HOST}/api/v1/api_entrypoint").once.returns(response_stub)
    @adapter.send(:get, '/api_entrypoint')

    get_request_expected("#{FAKE_API_HOST}/api/v1/api_entrypoint_without_leading_slash").once.returns(response_stub)
    @adapter.send(:get, 'api_entrypoint_without_leading_slash')
  end
  
  

  describe "when asked to establish pending queues list" do

    describe "and there is pending data awaiting for pull" do
      before do
        xml = <<-XML
          <pending_data>
            <queue name="pending_meta" products_count="24" last_insert_at="2011-02-05 21:02:22 UTC"/>      
            <queue name="pending_stocks" products_count="1500" last_insert_at="2011-02-05 21:02:22 UTC"/>         
          </pending_data>
        XML

        response_stub = stub('response_stub', :code => 200, :parsed_response => Nokogiri::XML(xml))
        get_request_expected("#{FAKE_API_HOST}/api/v1/queues/pending_data").at_least_once.returns(response_stub)
      end


      it "should return Queue instances with attributes filled from returned XML" do
        assert @adapter.pending_data?
        pending_queues = @adapter.pending_queues
        assert_equal 2, pending_queues.size

        pending_meta = pending_queues.find {|queue| queue.name == 'pending_meta' }
        pending_stocks = pending_queues.find {|queue| queue.name == 'pending_stocks' }

        assert_equal 24, pending_meta.products_count
        assert_kind_of Time, pending_meta.last_insert_at 

        assert_equal 1500, pending_stocks.products_count
        assert_kind_of Time, pending_stocks.last_insert_at 
      end
    end


    describe "and there is no pending data awaiting for pull" do
      before do
        xml = <<-XML
          <pending_data>
            <queue name="pending_meta" products_count="0" />      
            <queue name="pending_stocks" products_count="0" />         
          </pending_data>
        XML

        response_stub = stub('response_stub', :code => 200, :parsed_response => Nokogiri::XML(xml))
        get_request_expected("#{FAKE_API_HOST}/api/v1/queues/pending_data").at_least_once.returns(response_stub)
      end


      it "should return empty array and claim that there is no pending data" do
        assert @adapter.pending_queues.empty?
        assert !@adapter.pending_data?
      end
    end
  end
  
  

  describe "when asked to pick up queue" do
    before do
      xml = <<-XML
        <pick_up>
          <queue name="meta" id="192f134e666df34464bcc14d04135cda2bd13a0c" url="#{FAKE_API_HOST}/api/v1/queues/meta/192f134e666df34464bcc14d04135cda2bd13a0c" products_count="24" last_insert_at="2011-02-05 21:02:22 UTC" picked_up_at="2011-02-05 21:02:22 UTC"/>      
        </pick_up>
      XML

      @response_stub = stub('response_stub', :code => 200, :parsed_response => Nokogiri::XML(xml))
    end


    it "should be able to pick it up by name" do
      post_request_expected("#{FAKE_API_HOST}/api/v1/queues/pending_meta/pick_up").at_least_once.returns(@response_stub)
      picked_up_queue = @adapter.pick_up_queue!('pending_meta')
      assert_equal 24, picked_up_queue.products_count
      assert_kind_of Time, picked_up_queue.picked_up_at
    end
    
    
    it "should be able to pick it up by Queue instance" do
      post_request_expected("#{FAKE_API_HOST}/api/v1/queues/pending_meta/pick_up").at_least_once.returns(@response_stub)
      queue_to_pick_up = Elibri::ApiClient::ApiAdapters::V1::Queue.new(@api_adapter, :name => 'pending_meta')
      picked_up_queue = @adapter.pick_up_queue!(queue_to_pick_up)
      assert_equal 24, picked_up_queue.products_count
      assert_kind_of Time, picked_up_queue.picked_up_at
    end


    it "should raise error when cannot infer queue name from argument" do
      post_request_expected("#{FAKE_API_HOST}/api/v1/queues/pending_meta/pick_up").never
      post_request_expected("#{FAKE_API_HOST}/api/v1/queues/pending_stocks/pick_up").never

      assert_raises(RuntimeError) { @adapter.pick_up_queue!(12345) }
      assert_raises(RuntimeError) { @adapter.pick_up_queue!(Array.new) }
    end
  end
  


  describe "when there was error reported" do
    before do
      @xml = %q{<error id="ERROR_CODE"> <message>Error message for error ERROR_CODE</message> </error>}
      @exception_classes = {
        '404' =>  Elibri::ApiClient::ApiAdapters::V1::Exceptions::NotFound,
        '403' =>  Elibri::ApiClient::ApiAdapters::V1::Exceptions::Forbidden,
        '500' =>  Elibri::ApiClient::ApiAdapters::V1::Exceptions::ServerError,
        '1001' => Elibri::ApiClient::ApiAdapters::V1::Exceptions::QueueDoesNotExists,
        '1002' => Elibri::ApiClient::ApiAdapters::V1::Exceptions::NoPendingData,
        '1003' => Elibri::ApiClient::ApiAdapters::V1::Exceptions::NoRecentlyPickedUpQueues,
        '1004' => Elibri::ApiClient::ApiAdapters::V1::Exceptions::InvalidPageNumber
      }
    end


    it "should raise proper exception class" do
      @exception_classes.each do |error_code, exception_class|
        response_stub = stub('response_stub', :code => 200, :parsed_response => Nokogiri::XML( @xml.gsub('ERROR_CODE', error_code) ))
        get_request_expected("#{FAKE_API_HOST}/api/v1/queues/pending_data").once.returns(response_stub)
        assert_raises(exception_class) { @adapter.pending_queues }
      end  
    end


    it "should raise Unauthorized, when there is 401 response code" do
      response_stub = stub('response_stub', :code => 401, :parsed_response => nil)
      get_request_expected("#{FAKE_API_HOST}/api/v1/queues/pending_data").once.returns(response_stub)
      assert_raises(Elibri::ApiClient::ApiAdapters::V1::Exceptions::Unauthorized) { @adapter.pending_queues }
    end


    it "should raise RuntimeError on unknown error code" do
      response_stub = stub('response_stub', :code => 200, :parsed_response => Nokogiri::XML( @xml.gsub('ERROR_CODE', 'UNKNOWN_ERROR_CODE') ))
      get_request_expected("#{FAKE_API_HOST}/api/v1/queues/pending_data").once.returns(response_stub)
      assert_raises(Elibri::ApiClient::ApiAdapters::V1::Exceptions::UnknownError) { @adapter.pending_queues }
    end
    
  end



  describe "when asked to get latest pickups" do
    describe "and there is no recently picked up queues" do
      before do
        xml = %q{<error id='1003'> <message>There is no recently picked up queue</message> </error>}
        response_stub = stub('response_stub', :code => 412, :parsed_response => Nokogiri::XML(xml))
        get_request_expected("#{FAKE_API_HOST}/api/v1/queues/meta/last_pick_up").once.returns(response_stub)
        get_request_expected("#{FAKE_API_HOST}/api/v1/queues/stocks/last_pick_up").once.returns(response_stub)
      end

      it "should return empty latest pickups list" do
        assert @adapter.last_pickups.empty?
      end
    end


    describe "and there were recently picked up queues" do
      before do
        meta_xml = <<-XML
          <pick_up>
            <queue name="meta" id="192f134e666df34464bcc14d04135cda2bd13a0c" url="#{FAKE_API_HOST}/api/v1/queues/meta/192f134e666df34464bcc14d04135cda2bd13a0c" products_count="24" last_insert_at="2011-02-05 21:02:22 UTC" picked_up_at="2011-02-05 21:02:22 UTC"/>      
          </pick_up>
        XML

        stocks_xml = <<-XML
          <pick_up>
            <queue name="stocks" id="192f134e666df34464bcc14d04135cda2bd13a0d" url="#{FAKE_API_HOST}/api/v1/queues/stocks/192f134e666df34464bcc14d04135cda2bd13a0d" products_count="50" last_insert_at="2011-02-05 21:02:22 UTC" picked_up_at="2011-02-05 21:02:22 UTC"/>      
          </pick_up>
        XML

        meta_response_stub = stub('response_stub', :code => 200, :parsed_response => Nokogiri::XML(meta_xml))
        stocks_response_stub = stub('response_stub', :code => 200, :parsed_response => Nokogiri::XML(stocks_xml))
        get_request_expected("#{FAKE_API_HOST}/api/v1/queues/meta/last_pick_up").once.returns(meta_response_stub)
        get_request_expected("#{FAKE_API_HOST}/api/v1/queues/stocks/last_pick_up").once.returns(stocks_response_stub)
      end


      it "should return latest pickups as Queue instances" do
        last_pickups = @adapter.last_pickups
        assert_equal 2, last_pickups.size 
        assert(last_pickups.all? { |pickup| pickup.is_a? Elibri::ApiClient::ApiAdapters::V1::Queue })
      end
    end
  end



  describe "when asked to iterate by products in a queue" do
    before do
      @queue = Elibri::ApiClient::ApiAdapters::V1::Queue.new(@adapter, :name => 'meta', :queue_id => 'QUEUE_ID')
      first_page_xml = <<-XML
        <queue name="meta" id="QUEUE_ID" products_count="54" picked_up_at="2011-02-05 21:02:22 UTC">      
          <items paginated="true">
            <pages total="3" items_per_page="20" > 
              <next_page page_no="2" url="#{FAKE_API_HOST}/api/v1/queues/meta/QUEUE_ID/2" />      
              <current_page page_no="1" url="#{FAKE_API_HOST}/api/v1/queues/meta/QUEUE_ID" >
                <content><Product>PRODUCT_FROM_PAGE_1</Product></content>
              </current_page>
            </pages>
          </items>
        </queue>
      XML
      second_page_xml = <<-XML
        <queue name="meta" id="QUEUE_ID" products_count="54" picked_up_at="2011-02-05 21:02:22 UTC">      
          <items paginated="true">
            <pages total="3" items_per_page="20" > 
              <previous_page page_no="1" url="#{FAKE_API_HOST}/api/v1/queues/meta/QUEUE_ID" />      
              <next_page page_no="3" url="#{FAKE_API_HOST}/api/v1/queues/meta/QUEUE_ID/3" />      
              <current_page page_no="2" url="#{FAKE_API_HOST}/api/v1/queues/meta/QUEUE_ID/2" >
                <content><Product>PRODUCT_FROM_PAGE_2</Product></content>
              </current_page>
            </pages>
          </items>
        </queue>
      XML
      third_page_xml = <<-XML
        <queue name="meta" id="QUEUE_ID" products_count="54" picked_up_at="2011-02-05 21:02:22 UTC">      
          <items paginated="true">
            <pages total="3" items_per_page="20" > 
              <previous_page page_no="2" url="#{FAKE_API_HOST}/api/v1/queues/meta/QUEUE_ID/2" />      
              <current_page page_no="3" url="#{FAKE_API_HOST}/api/v1/queues/meta/QUEUE_ID/3" >
                <content><Product>PRODUCT_FROM_PAGE_3</Product></content>
              </current_page>
            </pages>
          </items>
        </queue>
      XML

      first_page_response_stub = stub('response1_stub', :code => 200, :parsed_response => Nokogiri::XML(first_page_xml))
      second_page_response_stub = stub('response2_stub', :code => 200, :parsed_response => Nokogiri::XML(second_page_xml))
      third_page_response_stub = stub('response3_stub', :code => 200, :parsed_response => Nokogiri::XML(third_page_xml))

      get_request_expected("#{FAKE_API_HOST}/api/v1/queues/meta/QUEUE_ID").once.returns(first_page_response_stub)
      get_request_expected("#{FAKE_API_HOST}/api/v1/queues/meta/QUEUE_ID/2").once.returns(second_page_response_stub)
      get_request_expected("#{FAKE_API_HOST}/api/v1/queues/meta/QUEUE_ID/3").once.returns(third_page_response_stub)
    end


    it "should be able to iterate through products pages" do
      expected_content = %w{<Product>PRODUCT_FROM_PAGE_1</Product> <Product>PRODUCT_FROM_PAGE_2</Product> <Product>PRODUCT_FROM_PAGE_3</Product>}
      @adapter.each_page_in_queue(@queue) do |page_content, page_no|
        assert_equal expected_content[page_no-1], page_content.children.to_s
      end
    end
    

    it "should be able to iterate through all product records" do
      expected_records = %w{PRODUCT_FROM_PAGE_1 PRODUCT_FROM_PAGE_2 PRODUCT_FROM_PAGE_3}
      @adapter.each_product_onix_in_queue(@queue) do |product_xml, product_no|
        assert_kind_of Nokogiri::XML::Element, product_xml
        assert_equal expected_records[product_no-1], product_xml.text
      end
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
            <product main_title="Erlang Programming" record_reference="04325b31fdece145d22e" url="#{FAKE_API_HOST}/api/v1/products/04325b31fdece145d22e"/>
            <product main_title="The Little Schemer" record_reference="993140a24d8202a347cc" url="#{FAKE_API_HOST}/api/v1/products/993140a24d8202a347cc"/>
            <product main_title="The Rails Way" record_reference="a40f41cf67facf1876e3" url="#{FAKE_API_HOST}/api/v1/products/a40f41cf67facf1876e3"/>
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
      assert_equal 'Erlang Programming', erlang_programming.main_title
      assert_equal '04325b31fdece145d22e', erlang_programming.record_reference
      assert_equal "#{FAKE_API_HOST}/api/v1/products/04325b31fdece145d22e", erlang_programming.url
    end
  end


  describe "when asked to product ONIX XML for specified product" do
    before do
      @product = Elibri::ApiClient::ApiAdapters::V1::Product.new(@adapter, stub('publisher'), :record_reference => '076eb83a5f01cb03a217')
      xml = %Q{<Product><RecordReference>076eb83a5f01cb03a217</RecordReference></Product>}
      response_stub = stub('response_stub', :code => 200, :parsed_response => Nokogiri::XML(xml))
      get_request_expected("#{FAKE_API_HOST}/api/v1/products/076eb83a5f01cb03a217").at_least_once.returns(response_stub)
    end


    it "should return parsed ONIX XML" do
      product_xml = @adapter.onix_xml_for_product(@product)
      assert_kind_of Nokogiri::XML::Element, product_xml
      assert_equal '076eb83a5f01cb03a217', product_xml.css('RecordReference').text
    end

  end
end
