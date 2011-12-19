
require 'helper'


describe Elibri::ApiClient::ApiAdapters::V1::QueuePop do

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
</ONIXMessage>
    XML
  end


  it "should have several attributes" do
    time = Time.now
    queue_pop = Elibri::ApiClient::ApiAdapters::V1::QueuePop.new(
      :queue_name => 'meta',
      :popped_products_count => 120,
      :created_at => time.to_s,
      :xml => @xml
    )

    assert_equal 'meta', queue_pop.queue_name 
    assert_equal 120, queue_pop.popped_products_count 
    assert_equal time.to_i, queue_pop.created_at.to_i
    assert_equal @xml, queue_pop.xml
    assert_kind_of Elibri::ONIX::Release_3_0::ONIXMessage, queue_pop.onix
    assert_equal 'fdb8fa072be774d97a97', queue_pop.onix.products.first.record_reference
  end
  

end
