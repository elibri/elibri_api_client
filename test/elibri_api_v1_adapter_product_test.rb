require 'helper'


describe Elibri::ApiClient::ApiAdapters::V1::Product do

  before do
    @api_adapter = mock('api_adapter')
    @publisher = stub('publisher', :name => 'Wydawnictwo')
  end


  it "should have several attributes" do
    product = Elibri::ApiClient::ApiAdapters::V1::Product.new(@api_adapter, @publisher,
      :product_id => '1111',
      :record_reference => 'AAAAAAAAAAAAAAA',
      :main_title => 'Erlang Programming',
      :url => 'http://api.elibri.com.pl/api/v1/products/1111'
    )

    assert_equal 'Erlang Programming', product.main_title 
    assert_equal 1111, product.product_id
    assert_equal 'AAAAAAAAAAAAAAA', product.record_reference
    assert_equal 'Wydawnictwo', product.publisher.name
  end
  


  it "should be able to build itself from provided XML" do
    xml = %Q{
      <product id="3" main_title="Erlang Programming" record_reference="04325b31fdece145d22e" url="http://api.elibri.com.pl/api/v1/products/3"/>
    }

    product = Elibri::ApiClient::ApiAdapters::V1::Product.build_from_xml(@api_adapter, @publisher, xml)

    assert_equal 3, product.product_id
    assert_equal 'Erlang Programming', product.main_title
    assert_equal '04325b31fdece145d22e', product.record_reference
    assert_equal "http://api.elibri.com.pl/api/v1/products/3", product.url
  end




end
