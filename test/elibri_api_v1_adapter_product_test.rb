require 'helper'


describe Elibri::ApiClient::ApiAdapters::V1::Product do

  before do
    @api_adapter = mock('api_adapter')
    @publisher = stub('publisher', :name => 'Wydawnictwo', :publisher_id => 1234)
  end


  it "should have several attributes" do
    product = Elibri::ApiClient::ApiAdapters::V1::Product.new(@api_adapter, @publisher,
      :record_reference => 'AAAAAAAAAAAAAAA',
      :title => 'Erlang Programming',
      :url => 'http://www.elibri.com.pl/api/v1/products/AAAAAAAAAAAAAAA'
    )

    assert_equal 'Erlang Programming', product.title 
    assert_equal 'AAAAAAAAAAAAAAA', product.record_reference
    assert_equal 'Wydawnictwo', product.publisher.name
  end
  


  it "should be able to build itself from provided XML" do
    xml = %Q{
      <product record_reference="04325b31fdece145d22e" title="Erlang Programming"  url="http://www.elibri.com.pl/api/v1/products/04325b31fdece145d22e"/>
    }

    product = Elibri::ApiClient::ApiAdapters::V1::Product.build_from_xml(@api_adapter, @publisher, xml)
    assert_equal 'Erlang Programming', product.title
    assert_equal '04325b31fdece145d22e', product.record_reference
    assert_equal "http://www.elibri.com.pl/api/v1/products/04325b31fdece145d22e", product.url
  end


  it "should be able to establish its full ONIX xml" do
    product = Elibri::ApiClient::ApiAdapters::V1::Product.new(@api_adapter, @publisher, :record_reference => '04325b31fdece145d22e')
    @api_adapter.expects(:onix_xml_for_product).with(product)
    product.onix_xml
  end
  
end
