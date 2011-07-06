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
      assert(Elibri::ApiClient::ApiAdapters::V1.const_get(exception_class) < RuntimeError)
    end  
  end
  

  it "should be able to refill all pending queues" do
    response_stub = stub('response_stub', :code => 200, :parsed_response => nil)
    post_request_expected("#{FAKE_API_HOST}/api/v1/queues/refill_all").returns(response_stub)

    @adapter.refill_all_queues!
  end
  

  describe "when asked to establish pending queues list" do

    describe "and there is pending data awaiting for pull" do
      before do
        xml = <<-XML
          <pending_data>
            <queue name="pending_meta" items_total="24" last_insert_at="2011-02-05 21:02:22 UTC"/>      
            <queue name="pending_stocks" items_total="1500" last_insert_at="2011-02-05 21:02:22 UTC"/>         
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

        assert_equal 24, pending_meta.items_total
        assert_kind_of Time, pending_meta.last_insert_at 

        assert_equal 1500, pending_stocks.items_total
        assert_kind_of Time, pending_stocks.last_insert_at 
      end
    end


    describe "and there is no pending data awaiting for pull" do
      before do
        xml = <<-XML
          <pending_data>
            <queue name="pending_meta" items_total="0" />      
            <queue name="pending_stocks" items_total="0" />         
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
          <queue name="meta" id="192f134e666df34464bcc14d04135cda2bd13a0c" url="#{FAKE_API_HOST}/api/v1/queues/meta/192f134e666df34464bcc14d04135cda2bd13a0c" items_total="24" last_insert_at="2011-02-05 21:02:22 UTC" picked_up_at="2011-02-05 21:02:22 UTC"/>      
        </pick_up>
      XML

      @response_stub = stub('response_stub', :code => 200, :parsed_response => Nokogiri::XML(xml))
    end


    it "should be able to pick it up by name" do
      post_request_expected("#{FAKE_API_HOST}/api/v1/queues/pending_meta/pick_up").at_least_once.returns(@response_stub)
      picked_up_queue = @adapter.pick_up_queue!('pending_meta')
      assert_equal 24, picked_up_queue.items_total
      assert_kind_of Time, picked_up_queue.picked_up_at
    end
    
    
    it "should be able to pick it up by Queue instance" do
      post_request_expected("#{FAKE_API_HOST}/api/v1/queues/pending_meta/pick_up").at_least_once.returns(@response_stub)
      queue_to_pick_up = Elibri::ApiClient::ApiAdapters::V1::Queue.new(@api_adapter, :name => 'pending_meta')
      picked_up_queue = @adapter.pick_up_queue!(queue_to_pick_up)
      assert_equal 24, picked_up_queue.items_total
      assert_kind_of Time, picked_up_queue.picked_up_at
    end


    it "should raise error when cannot infer queue name from argument" do
      post_request_expected("#{FAKE_API_HOST}/api/v1/queues/pending_meta/pick_up").never
      post_request_expected("#{FAKE_API_HOST}/api/v1/queues/pending_stocks/pick_up").never

      assert_raises(RuntimeError) { @adapter.pick_up_queue!(12345) }
      assert_raises(RuntimeError) { @adapter.pick_up_queue!(Array.new) }
    end
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
  
  
  describe "when there was error reported" do
    before do
      @xml = %q{<error id="ERROR_CODE"> <message>Error message for error ERROR_CODE</message> </error>}
      @exception_classes = {
        '404' =>  Elibri::ApiClient::ApiAdapters::V1::NotFound,
        '403' =>  Elibri::ApiClient::ApiAdapters::V1::Forbidden,
        '500' =>  Elibri::ApiClient::ApiAdapters::V1::ServerError,
        '1001' => Elibri::ApiClient::ApiAdapters::V1::QueueDoesNotExists,
        '1002' => Elibri::ApiClient::ApiAdapters::V1::NoPendingData,
        '1003' => Elibri::ApiClient::ApiAdapters::V1::NoRecentlyPickedUpQueues,
        '1004' => Elibri::ApiClient::ApiAdapters::V1::InvalidPageNumber
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
      assert_raises(Elibri::ApiClient::ApiAdapters::V1::Unauthorized) { @adapter.pending_queues }
    end


    it "should raise RuntimeError on unknown error code" do
      response_stub = stub('response_stub', :code => 200, :parsed_response => Nokogiri::XML( @xml.gsub('ERROR_CODE', 'UNKNOWN_ERROR_CODE') ))
      get_request_expected("#{FAKE_API_HOST}/api/v1/queues/pending_data").once.returns(response_stub)
      assert_raises(Elibri::ApiClient::ApiAdapters::V1::UnknownError) { @adapter.pending_queues }
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
            <queue name="meta" id="192f134e666df34464bcc14d04135cda2bd13a0c" url="#{FAKE_API_HOST}/api/v1/queues/meta/192f134e666df34464bcc14d04135cda2bd13a0c" items_total="24" last_insert_at="2011-02-05 21:02:22 UTC" picked_up_at="2011-02-05 21:02:22 UTC"/>      
          </pick_up>
        XML

        stocks_xml = <<-XML
          <pick_up>
            <queue name="stocks" id="192f134e666df34464bcc14d04135cda2bd13a0d" url="#{FAKE_API_HOST}/api/v1/queues/stocks/192f134e666df34464bcc14d04135cda2bd13a0d" items_total="50" last_insert_at="2011-02-05 21:02:22 UTC" picked_up_at="2011-02-05 21:02:22 UTC"/>      
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


  describe "when asked to iterate by products" do

    before do
      @queue = Elibri::ApiClient::ApiAdapters::V1::Queue.new(@adapter, :name => 'meta', :queue_id => 'QUEUE_ID')

      first_page_xml = <<-XML
        <queue name="meta" id="QUEUE_ID" items_total="54" picked_up_at="2011-02-05 21:02:22 UTC">      
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
        <queue name="meta" id="QUEUE_ID" items_total="54" picked_up_at="2011-02-05 21:02:22 UTC">      
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
        <queue name="meta" id="QUEUE_ID" items_total="54" picked_up_at="2011-02-05 21:02:22 UTC">      
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


    it "should be able to iterate through page products" do
      expected_content = %w{<Product>PRODUCT_FROM_PAGE_1</Product> <Product>PRODUCT_FROM_PAGE_2</Product> <Product>PRODUCT_FROM_PAGE_3</Product>}
      @adapter.each_page(@queue) do |page_content, page_no|
        assert_equal expected_content[page_no-1], page_content.children.to_s
      end
    end
    

    it "should be able to iterate through all product records" do
      expected_records = %w{PRODUCT_FROM_PAGE_1 PRODUCT_FROM_PAGE_2 PRODUCT_FROM_PAGE_3}
      @adapter.each_product(@queue) do |product_xml, product_no|
        assert_equal expected_records[product_no-1], product_xml.text
      end
    end
  end

end
