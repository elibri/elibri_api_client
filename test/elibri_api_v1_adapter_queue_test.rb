require 'helper'


describe Elibri::ApiClient::ApiAdapters::V1::Queue do

  before do
    @api_adapter = mock('api_adapter')
  end


  it "should have several attributes" do
    time = Time.now
    queue = Elibri::ApiClient::ApiAdapters::V1::Queue.new(@api_adapter,
      :name => 'meta',
      :products_count => 120,
      :last_insert_at => time.to_s
    )

    assert_equal 'meta', queue.name 
    assert_equal 120, queue.products_count
    assert_equal time.to_i, queue.last_insert_at.to_i
  end
  

  it "should be able to build itself from provided XML" do
    xml = %Q{<queue name="stocks" products_count="1500" last_insert_at="2011-02-05 21:02:22 UTC" />}

    queue = Elibri::ApiClient::ApiAdapters::V1::Queue.build_from_xml(@api_adapter, xml)
    assert_equal 'stocks', queue.name 
    assert_equal 1500, queue.products_count
    assert_equal Time.parse("2011-02-05 21:02:22 UTC"), queue.last_insert_at 
  end
  

  it "should be able to pop data from itself" do
    queue = Elibri::ApiClient::ApiAdapters::V1::Queue.new(@api_adapter, :name => 'meta')
    @api_adapter.expects(:pop_from_queue).with(queue.name, {:testing => 1, :count => 20})
    queue.pop(:testing => 1, :count => 20)
  end
  

  it "should be able to establish last pop from itself" do
    queue = Elibri::ApiClient::ApiAdapters::V1::Queue.new(@api_adapter, :name => 'meta')
    @api_adapter.expects(:last_pop_from_queue).with('meta')
    queue.last_pop
  end
  

  it "should provide iterator for traversing through each pop" do
    queue = Elibri::ApiClient::ApiAdapters::V1::Queue.new(@api_adapter, :name => 'meta')
    pop_with_products = stub('QueuePop', :popped_products_count => 5)
    pop_with_products2 = stub('QueuePop', :popped_products_count => 3)
    queue.expects(:pop).with(:count => 5).returns(pop_with_products).then.returns(pop_with_products2).then.returns(nil).times(3)

    pops = []
    queue.each_pop(:count => 5) {|pop| pops << pop  }
    assert_equal [pop_with_products, pop_with_products2], pops
  end
  

end
