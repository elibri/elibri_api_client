
require 'helper'


describe Elibri::ApiClient::ApiAdapters::V1::QueuePop do

  before do
    @products_xmls = Nokogiri::XML(<<-XML).css('Product')
      <root>
        <Product>
          <RecordReference>123</RecordReference>
        </Product>
        <Product>
          <RecordReference>456</RecordReference>
        </Product>
      </root>
    XML
  end


  it "should have several attributes" do
    time = Time.now
    queue_pop = Elibri::ApiClient::ApiAdapters::V1::QueuePop.new(
      :queue_name => 'meta',
      :popped_products_count => 120,
      :created_at => time.to_s,
      :products_xmls => @products_xmls
    )

    assert_equal 'meta', queue_pop.queue_name 
    assert_equal 120, queue_pop.popped_products_count 
    assert_equal time.to_i, queue_pop.created_at.to_i
    assert_equal @products_xmls, queue_pop.products_xmls
  end
  

  it "should be able to build itself from provided XML" do
    xml = <<-XML
      <pop queue_name="meta" popped_products_count="1500" created_at="2011-02-05 21:02:22 UTC">
        #{@products_xmls.to_s}
      </pop>
    XML

    queue_pop = Elibri::ApiClient::ApiAdapters::V1::QueuePop.build_from_xml(xml)
    assert_equal 'meta', queue_pop.queue_name 
    assert_equal 1500, queue_pop.popped_products_count
    assert_equal Time.parse("2011-02-05 21:02:22 UTC"), queue_pop.created_at 
    assert_equal 2, queue_pop.products_xmls.size
  end
  

  it "should provide iterator for traversing products list" do
    xml = <<-XML
      <pop queue_name="meta" popped_products_count="1500" created_at="2011-02-05 21:02:22 UTC">
        #{@products_xmls.to_s}
      </pop>
    XML

    queue_pop = Elibri::ApiClient::ApiAdapters::V1::QueuePop.build_from_xml(xml)
    record_references = []
    queue_pop.each_product {|product_xml| record_references << product_xml.css('RecordReference').text  }
    assert_equal ['123', '456'], record_references
  end
  

end
