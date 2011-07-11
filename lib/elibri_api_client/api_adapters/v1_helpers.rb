
# Klasy pomocnicze dla API w wersji 1
module Elibri
  class ApiClient
    module ApiAdapters

      # Adapter dla pierwszej wersji API.
      class V1

        class UnknownError < RuntimeError; end
        class Unauthorized < RuntimeError; end
        class NotFound < RuntimeError; end
        class Forbidden < RuntimeError; end
        class ServerError < RuntimeError; end
        class NoPendingData < RuntimeError; end
        class NoRecentlyPickedUpQueues < RuntimeError; end
        class QueueDoesNotExists < RuntimeError; end
        class InvalidPageNumber < RuntimeError; end

        # Klasy wyjatkow rzucanych, gdy elibri zwroci okreslony blad. Np. gdy dostaniemy:
        #   <error id="1001">
        #     <message>Queue does not exist</message>
        #   </error>
        # Biblioteka rzuca wyjatkiem QueueDoesNotExists.
        EXCEPTION_CLASSES = {
          '404' => NotFound,
          '403' => Forbidden,
          '500' => ServerError,
          '1001' => QueueDoesNotExists,
          '1002' => NoPendingData,
          '1003' => NoRecentlyPickedUpQueues,
          '1004' => InvalidPageNumber
        }.freeze


        # Zamiast rzezbic ciagle w XML`u, tworzymy instancje kolejek.
        class Queue
          attr_reader :name, :items_total, :picked_up_at, :last_insert_at, :queue_id, :url

          def initialize(api_adapter, attributes = {})
            @api_adapter = api_adapter
            @name = attributes[:name]
            @items_total = attributes[:items_total].to_i
            @queue_id = attributes[:queue_id]
            @url = attributes[:url]

            @last_insert_at = Time.parse(attributes[:last_insert_at]) if attributes[:last_insert_at].present?
            @picked_up_at = Time.parse(attributes[:picked_up_at]) if attributes[:picked_up_at].present?
          end


          # Przekonwertuj kolejke z danymi oczekujacymi (np. 'pending_meta') na kolejke nazwana.
          def pick_up!
            @api_adapter.pick_up_queue!(self) unless picked_up?
          end


          # Hermetyzujemy stronicowanie danych. Programiste interesuja tylko kolejne rekordy <Product>
          def each_product(&block)
            @api_adapter.each_product(self, &block)
          end


          # Czy to jest kolejka nazwana, czy oczekujaca? Wszystkie kolejki z danymi oczekujacymi maja w nazwie
          # przedrostek 'pending_'. Np. 'pending_meta', 'pending_stocks'.
          def picked_up?
            !self.name.start_with?('pending_')
          end


          # Zbuduj instancje kolejki na podstawie XML`a.
          def self.build_from_xml(api_adapter, queue_xml)
            queue_xml = Nokogiri::XML(queue_xml).css('queue').first if queue_xml.is_a? String
            Queue.new(api_adapter,
              :name => queue_xml['name'],
              :items_total => queue_xml['items_total'].to_i,
              :last_insert_at => queue_xml['last_insert_at'],
              :url => queue_xml['url'],
              :queue_id => queue_xml['id'],
              :picked_up_at => queue_xml['picked_up_at']
            )
          end
          

        end


      end
    end
  end
end
