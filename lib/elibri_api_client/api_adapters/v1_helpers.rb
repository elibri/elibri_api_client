
# Klasy pomocnicze dla API w wersji 1
module Elibri
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
          class NoPendingData < RuntimeError; end
          class NoRecentlyPickedUpQueues < RuntimeError; end
          class QueueDoesNotExists < RuntimeError; end
          class InvalidPageNumber < RuntimeError; end
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
          '1002' => Exceptions::NoPendingData,
          '1003' => Exceptions::NoRecentlyPickedUpQueues,
          '1004' => Exceptions::InvalidPageNumber
        }.freeze


        # Zamiast rzezbic ciagle w XML`u, tworzymy instancje kolejek.
        class Queue
          attr_reader :name, :products_count, :picked_up_at, :last_insert_at, :queue_id, :url

          def initialize(api_adapter, attributes = {}) #:nodoc:
            @api_adapter = api_adapter
            @name = attributes[:name]
            @products_count = attributes[:products_count].to_i
            @queue_id = attributes[:queue_id]
            @url = attributes[:url]

            @last_insert_at = Time.parse(attributes[:last_insert_at]) if attributes[:last_insert_at].present?
            @picked_up_at = Time.parse(attributes[:picked_up_at]) if attributes[:picked_up_at].present?
          end


          # Przekonwertuj kolejke z danymi oczekujacymi (np. 'pending_meta') na kolejke nazwana.
          def pick_up!
            @api_adapter.pick_up_queue!(self) unless picked_up?
          end


          # Iteruj po kolejnych rekordach ONIX w nazwanej kolejce.
          def each_product_onix(&block)
            raise 'Cannot iterate unpicked queue products! Try named = queue.pick_up! and then named.each_product_onix' unless self.picked_up?
            @api_adapter.each_product_onix_in_queue(self, &block)
          end


          # Czy to jest kolejka nazwana, czy oczekujaca? Wszystkie kolejki z danymi oczekujacymi maja w nazwie
          # przedrostek 'pending_'. Np. 'pending_meta', 'pending_stocks'.
          def picked_up?
            !self.name.start_with?('pending_')
          end


          # Zbuduj instancje kolejki na podstawie XML`a.
          def self.build_from_xml(api_adapter, queue_xml) #:nodoc:
            queue_xml = Nokogiri::XML(queue_xml).css('queue').first if queue_xml.is_a? String
            Queue.new(api_adapter,
              :name => queue_xml['name'],
              :products_count => queue_xml['products_count'].to_i,
              :last_insert_at => queue_xml['last_insert_at'],
              :url => queue_xml['url'],
              :queue_id => queue_xml['id'],
              :picked_up_at => queue_xml['picked_up_at']
            )
          end
        end



        class Publisher
          attr_reader :publisher_id, :name, :products_count, :products_url, :company_name, :nip
          attr_reader :street, :city, :zip_code, :phone1, :phone2, :www, :email


          def initialize(api_adapter, attributes = {}) #:nodoc:
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
          attr_reader :publisher, :product_id, :record_reference, :main_title, :url

          def initialize(api_adapter, publisher, attributes = {}) #:nodoc:
            @api_adapter = api_adapter
            @publisher = publisher
            @product_id = attributes[:product_id].to_i
            @record_reference = attributes[:record_reference]
            @main_title = attributes[:main_title]
            @url = attributes[:url]
          end


          def onix_xml
            @api_adapter.onix_xml_for_product(self)
          end


          # Zbuduj instancje produktu na podstawie XML`a.
          def self.build_from_xml(api_adapter, publisher, product_xml) #:nodoc:
            product_xml = Nokogiri::XML(product_xml).css('product').first if product_xml.is_a? String
            Product.new(api_adapter, publisher,
              :product_id => product_xml['id'].to_i,
              :record_reference => product_xml['record_reference'],
              :url => product_xml['url'],
              :main_title => product_xml['main_title']
            )
          end

        end


      end
    end
  end
end
