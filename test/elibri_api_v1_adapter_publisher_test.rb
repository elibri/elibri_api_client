require 'helper'


describe Elibri::ApiClient::ApiAdapters::V1::Publisher do

  before do
    @api_adapter = mock('api_adapter')
  end


  it "should have several attributes" do
    publisher = Elibri::ApiClient::ApiAdapters::V1::Publisher.new(@api_adapter,
      :name => 'Wydawnicta Naukowo-Techniczne',
      :publisher_id => '1020',
      :products_count => 1503,
      :products_url => 'http://api.elibri.com.pl/api/v1/publishers/1020/products'
    )

    assert_equal 'Wydawnicta Naukowo-Techniczne', publisher.name 
    assert_equal 1020, publisher.publisher_id
    assert_equal 1503, publisher.products_count
    assert_equal 'http://api.elibri.com.pl/api/v1/publishers/1020/products', publisher.products_url
  end
  


  it "should be able to build itself from provided XML" do
    xml = %Q{
      <publishers>
        <publisher name="Wydawnicta Naukowo-Techniczne" city="Kraków" company_name="WNT Polska Sp. z o.o." zip_code="30-417" id="1" street="Łagiewnicka 33a" phone1="(12) 252-85-92" phone2="(12) 252-85-80" nip="679-284-08-64" www="http://www.wnt.com" email="sprzedaz@wnt.com">
          <products url="http://api.elibri.com.pl/api/v1/publishers/1/products" count="350"/>
        </publisher>
      </publishers>
    }

    publisher = Elibri::ApiClient::ApiAdapters::V1::Publisher.build_from_xml(@api_adapter, xml)

    assert_equal 1, publisher.publisher_id
    assert_equal 350, publisher.products_count
    assert_equal "Wydawnicta Naukowo-Techniczne", publisher.name
    assert_equal "WNT Polska Sp. z o.o.", publisher.company_name
    assert_equal "Kraków", publisher.city
    assert_equal "30-417", publisher.zip_code
    assert_equal "Łagiewnicka 33a", publisher.street
    assert_equal "(12) 252-85-92", publisher.phone1
    assert_equal "(12) 252-85-80", publisher.phone2
    assert_equal "679-284-08-64", publisher.nip
    assert_equal "http://www.wnt.com", publisher.www
    assert_equal "sprzedaz@wnt.com", publisher.email
    assert_equal 'http://api.elibri.com.pl/api/v1/publishers/1/products', publisher.products_url
  end


  it "should be able to establish its products list" do
    publisher = Elibri::ApiClient::ApiAdapters::V1::Publisher.new(@api_adapter, :publisher_id => 1234)
    @api_adapter.expects(:products_for_publisher).with(publisher)
    publisher.products
  end
  

end
