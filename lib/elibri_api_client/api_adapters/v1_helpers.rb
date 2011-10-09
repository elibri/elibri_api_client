
# Klasy pomocnicze dla API w wersji 1
module Elibri #:nodoc:
  class ApiClient
    module ApiAdapters

      # Adapter dla pierwszej wersji API.
      class V1

        module Exceptions #:nodoc:all
          class UnknownError < RuntimeError; end
          class Unauthorized < RuntimeError; end
          class NotFound < RuntimeError; end
          class Forbidden < RuntimeError; end
          class ServerError < RuntimeError; end
          class QueueDoesNotExists < RuntimeError; end
          class NoRecentlyPoppedData < RuntimeError; end
          class InvalidOnixDialect < RuntimeError; end
        end

        # Klasy wyjatkow rzucanych, gdy elibri zwroci okreslony blad. Np. gdy dostaniemy:
        #   <error id="1001">
        #     <message>Queue does not exist</message>
        #   </error>
        # Biblioteka rzuca wyjatkiem Elibri::ApiClient::ApiAdapters::V1::Exceptions::QueueDoesNotExists.
        EXCEPTION_CLASSES = {
          '404' =>  Exceptions::NotFound,
          '403' =>  Exceptions::Forbidden,
          '500' =>  Exceptions::ServerError,
          '1001' => Exceptions::QueueDoesNotExists,
          '1002' => Exceptions::NoRecentlyPoppedData,
          '1003' => Exceptions::InvalidOnixDialect,
        }.freeze


        # Zamiast rzezbic ciagle w XML`u, tworzymy instancje kolejek.
        class Queue
          # Nazwa kolejki - te z przedroskiem 'pending' sa oczekujace
          attr_reader :name
          # Ilosc produktow znajdujacych sie w kolejce
          attr_reader :products_count
          # Kiedy ostatnio umieszczono jakis produkt w kolejce?
          attr_reader :last_insert_at


          def initialize(api_adapter, attributes = {}) #:nodoc:
            attributes.assert_valid_keys(:name, :products_count, :last_insert_at)
            @api_adapter = api_adapter
            @name = attributes[:name]
            @products_count = attributes[:products_count].to_i
            @last_insert_at = Time.parse(attributes[:last_insert_at]) if attributes[:last_insert_at].present?
          end


          # Pobierz dane z kolejki
          def pop(options = {})
            @api_adapter.pop_from_queue(self.name, options)
          end


          # Zwroc ostatnio pobrane dane z tej kolejki
          def last_pop
            @api_adapter.last_pop_from_queue(self.name)
          end


          # Iteruj po kolejnych POP`ach w nazwanej kolejce.
          def each_pop(options = {}, &block) #:yields: QueuePop
            while _pop = pop(options)
              yield _pop
            end
          end


          # Zbuduj instancje kolejki na podstawie XML`a.
          def self.build_from_xml(api_adapter, queue_xml) #:nodoc:
            queue_xml = Nokogiri::XML(queue_xml).css('queue').first if queue_xml.is_a? String
            Queue.new(api_adapter,
              :name => queue_xml['name'],
              :products_count => queue_xml['products_count'].to_i,
              :last_insert_at => queue_xml['last_insert_at']
            )
          end
        end



        class QueuePop
          # Nazwa kolejki ktorej dotyczyl POP
          attr_reader :queue_name
          # Ilosc produktow pobranych w tym POPie
          attr_reader :popped_products_count
          # Kiedy POP zostal wykonany?
          attr_reader :created_at
          # Pelna tresc ONIX - lacznie z naglowkiem
          attr_reader :xml
          # ONIX przeparsowany za pomoca gemu elibri_onix
          attr_reader :onix


          def initialize(attributes = {}) #:nodoc:
            attributes.assert_valid_keys(:queue_name, :popped_products_count, :created_at, :xml)
            @queue_name = attributes[:queue_name]
            @popped_products_count = attributes[:popped_products_count].to_i
            @xml = attributes[:xml]
            @created_at = Time.parse(attributes[:created_at]) rescue nil
            @onix = Elibri::ONIX::Release_3_0::ONIXMessage.from_xml(@xml) if @xml.present?
          end

        end



        class Publisher
          # Identyfikator wydawnictwa w bazie
          attr_reader :publisher_id
          # Nazwa wlasna wydawnictwa
          attr_reader :name
          # Ilosc wydanych produktow
          attr_reader :products_count
          # Entrypoint API, pod ktorym mozna zobaczyc liste produktow
          attr_reader :products_url
          # Nazwa wydawnictwa jako firmy
          attr_reader :company_name
          # NIP
          attr_reader :nip
          # Ulica
          attr_reader :street
          # Miasto
          attr_reader :city
          # Kod pocztowy
          attr_reader :zip_code
          # Telefon 1
          attr_reader :phone1
          # Telefon 2
          attr_reader :phone2
          # Adres WWW wydawnictwa
          attr_reader :www
          # E-mail kontaktowy
          attr_reader :email


          def initialize(api_adapter, attributes = {}) #:nodoc:
            attributes.assert_valid_keys(
              :publisher_id, :name, :products_count, :products_url, :company_name, :nip, :street, :city, :zip_code, :phone1, :phone2, :www, :email
            )
            @api_adapter = api_adapter
            @publisher_id = attributes[:publisher_id].to_i
            @name = attributes[:name]
            @products_count = attributes[:products_count].to_i
            @products_url = attributes[:products_url]
            @company_name = attributes[:company_name]
            @nip = attributes[:nip]
            @street = attributes[:street]
            @city = attributes[:city]
            @zip_code = attributes[:zip_code]
            @phone1 = attributes[:phone1]
            @phone2 = attributes[:phone2]
            @www = attributes[:www]
            @email = attributes[:email]
          end


          # Zwroc liste produktow wydanych w wydawnictwie - instancji Elibri::ApiClient::ApiAdapters::V1::Product
          # call-seq:
          #   products -> array 
          #
          def products
            @api_adapter.products_for_publisher(self)
          end


          # Zbuduj instancje wydawnictwa na podstawie XML`a.
          def self.build_from_xml(api_adapter, publisher_xml) #:nodoc:
            publisher_xml = Nokogiri::XML(publisher_xml).css('publisher').first if publisher_xml.is_a? String
            Publisher.new(api_adapter,
              :name => publisher_xml['name'],
              :publisher_id => publisher_xml['id'].to_i,
              :company_name => publisher_xml['company_name'],
              :nip => publisher_xml['nip'],
              :street => publisher_xml['street'],
              :city => publisher_xml['city'],
              :zip_code => publisher_xml['zip_code'],
              :phone1 => publisher_xml['phone1'],
              :phone2 => publisher_xml['phone2'],
              :www => publisher_xml['www'],
              :email => publisher_xml['email'],
              :products_count => publisher_xml.css('products').first['count'].to_i,
              :products_url => publisher_xml.css('products').first['url']
            )
          end

        end



        class Product
          # Wydawnictwo, ktore opublikowalo produkt - instancja Elibri::ApiClient::ApiAdapters::V1::Publisher
          attr_reader :publisher
          # Unikalny identyfikator produktu w ONIX
          attr_reader :record_reference
          # Tytul produktu
          attr_reader :title
          # Entrypoint API, pod ktorym mozna pobrac ONIX produktu
          attr_reader :url

          def initialize(api_adapter, publisher, attributes = {}) #:nodoc:
            attributes.assert_valid_keys(:record_reference, :title, :url)
            @api_adapter = api_adapter
            @publisher = publisher
            @record_reference = attributes[:record_reference]
            @title = attributes[:title]
            @url = attributes[:url]
          end


          # Zwroc przeparsowany za pomoca Nokogiri ONIX produktu, pobrany z Elibri
          # call-seq:
          #   onix_xml -> nokogiri_parsed_xml
          #
          def onix_xml
            @api_adapter.onix_xml_for_product(self)
          end


          # Zbuduj instancje produktu na podstawie XML`a.
          def self.build_from_xml(api_adapter, publisher, product_xml) #:nodoc:
            product_xml = Nokogiri::XML(product_xml).css('product').first if product_xml.is_a? String
            Product.new(api_adapter, publisher,
              :record_reference => product_xml['record_reference'],
              :url => product_xml['url'],
              :title => product_xml['title']
            )
          end

        end


      end
    end
  end
end
