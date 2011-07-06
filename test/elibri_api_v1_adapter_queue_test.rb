require 'helper'


describe Elibri::ApiClient::ApiAdapters::V1::Queue do

  before do
    @api_adapter = mock('api_adapter')
  end


  it "should have several attributes" do
    time = Time.now
    queue = Elibri::ApiClient::ApiAdapters::V1::Queue.new(@api_adapter,
      :name => 'meta',
      :items_total => 120,
      :queue_id => '192f134e666df34464bcc14d0413',
      :url => 'http://api.elibri.com.pl/api/v1/queues/meta/192f134e666df34464bcc14d0413',
      :last_insert_at => time.to_s,
      :picked_up_at => time.to_s
    )

    assert_equal 'meta', queue.name 
    assert_equal 120, queue.items_total
    assert_equal '192f134e666df34464bcc14d0413', queue.queue_id
    assert_equal 'http://api.elibri.com.pl/api/v1/queues/meta/192f134e666df34464bcc14d0413', queue.url
    assert_equal time.to_i, queue.last_insert_at.to_i
    assert_equal time.to_i, queue.picked_up_at.to_i
  end
  


  it "should be able to build itself from provided XML" do
    xml = %Q{<queue name="stocks" id="192f134e666df34464bcc14d04135cda2bd13a0c" url="http://api.elibri.com.pl/api/v1/queues/stocks/192f134e666df34464bcc14d04135cda2bd13a0c" items_total="1500" last_insert_at="2011-02-05 21:02:22 UTC" picked_up_at="2011-02-05 22:02:22 UTC"/>}

    queue = Elibri::ApiClient::ApiAdapters::V1::Queue.build_from_xml(@api_adapter, xml)
    assert_equal 'stocks', queue.name 
    assert_equal 1500, queue.items_total
    assert_equal '192f134e666df34464bcc14d04135cda2bd13a0c', queue.queue_id
    assert_equal 'http://api.elibri.com.pl/api/v1/queues/stocks/192f134e666df34464bcc14d04135cda2bd13a0c', queue.url
    assert_equal Time.parse("2011-02-05 21:02:22 UTC"), queue.last_insert_at 
    assert_equal Time.parse("2011-02-05 22:02:22 UTC"), queue.picked_up_at

    xml = %Q{<queue name="pending_stocks" items_total="1500" last_insert_at="2011-02-05 21:02:22 UTC"/>}
    queue = Elibri::ApiClient::ApiAdapters::V1::Queue.build_from_xml(@api_adapter, xml)
    assert_nil queue.queue_id
    assert_nil queue.picked_up_at
    assert_nil queue.url
  end
  

  it "should be able to establish if its a picked up queue" do
    queue = Elibri::ApiClient::ApiAdapters::V1::Queue.new(@api_adapter, :name => 'pending_meta')
    assert !queue.picked_up?

    queue = Elibri::ApiClient::ApiAdapters::V1::Queue.new(@api_adapter, :name => 'meta')
    assert queue.picked_up?
  end
  
  
  
  
  it "should be able to pick up itself when its a pending queue" do
    queue = Elibri::ApiClient::ApiAdapters::V1::Queue.new(@api_adapter, :name => 'pending_meta')
    @api_adapter.expects(:pick_up_queue!).with(queue)
    queue.pick_up!
    
    queue = Elibri::ApiClient::ApiAdapters::V1::Queue.new(@api_adapter, :name => 'meta')
    @api_adapter.expects(:pick_up_queue!).with(queue).never
    queue.pick_up!
  end
  
  

  it "should provide iterator for traversing products list" do
    block = lambda {|product_xml| product_xml.css('RecordReference')  }

    queue = Elibri::ApiClient::ApiAdapters::V1::Queue.new(@api_adapter, :name => 'meta')
    @api_adapter.expects(:each_product).with(queue)
    queue.each_product(&block)
  end
  
  



end
