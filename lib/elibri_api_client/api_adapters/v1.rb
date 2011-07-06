require 'elibri_api_client/api_adapters/v1_helpers'

module Elibri
  class ApiClient
    module ApiAdapters

      # Adapter dla 1 wersji API
      class V1
        URI_PREFIX = '/api/v1'

        include HTTParty
        debug_output $stderr


        def initialize(host_uri, login, password)
          @host_uri = host_uri
          @auth = {:username => login, :password => password}
        end


        # Wypełnij wszystkie kolejki oczekujące, wszystkimi dostępnymi danymi. Przydatne przy wykonywaniu
        # pełnej synchronizacji pomiędzy naszą aplikacją a Elibri.
        def refill_all_queues!
          # Dla POST musi być jakieś 'body' requestu, bo serwery często rzucają wyjątkami (WEBrick w szczególności).
          post '/queues/refill_all', :body => ' '
        end


        # Zwróć listę kolejek z oczekującymi danymi.
        def pending_queues
          resp = get '/queues/pending_data'

          pending_queues = []
          resp.parsed_response.css('queue').each do |queue_xml|
            queue = Elibri::ApiClient::ApiAdapters::V1::Queue.build_from_xml(self, queue_xml)
            pending_queues << queue if queue.items_total.nonzero?
          end  
          pending_queues
        end


        # Czy są jakieś oczekujące dane w Elibri?
        def pending_data?
          !pending_queues.empty?
        end


        # Utwórz z danych oczekujących w kolejce np. 'pending_meta', kolejkę nazwaną.
        # Tylko z kolejek nazwanych można pobierać dane. Jako argument przyjmuje nazwę kolejki (np. 'pending_meta')
        # lub odpowiednią instancję Elibri::ApiClient::ApiAdapters::V1::Queue.
        def pick_up_queue!(queue)
          case queue
            when Elibri::ApiClient::ApiAdapters::V1::Queue
              queue_name = queue.name
            when String
              queue_name = queue
            else
              raise 'Specify queue as name or Elibri::ApiClient::ApiAdapters::V1::Queue instance'
          end

          response = post "/queues/#{queue_name}/pick_up", :body => ' '
          picked_up_queue_xml = response.parsed_response.css('pick_up queue').first
          Elibri::ApiClient::ApiAdapters::V1::Queue.build_from_xml(self, picked_up_queue_xml)
        end


        def each_page(queue, &block)
          raise 'Need a Elibri::ApiClient::ApiAdapters::V1::Queue instance' unless queue.kind_of? Elibri::ApiClient::ApiAdapters::V1::Queue
          
          page_no = 1
          response = get "/queues/#{queue.name}/#{queue.queue_id}"
          yield response.parsed_response.css('current_page content'), page_no
          while next_page = response.parsed_response.css('next_page').first
            response = get next_page['url']
            page_no += 1
            yield response.parsed_response.css('current_page content').first, page_no
          end
        end


        def each_product(queue, &block)
          raise 'Need a Elibri::ApiClient::ApiAdapters::V1::Queue instance' unless queue.kind_of? Elibri::ApiClient::ApiAdapters::V1::Queue

          product_no = 1
          each_page(queue) do |products_page_xml, page_no|
            products_page_xml.css('Product').each do |product_xml|
              block.call(product_xml, product_no)
              product_no += 1
            end  
          end
        end


        # Ostatnio utworzone nazwane kolejki. Gdy wysypie nam się aplikacja, można przeglądać ostatnie pickupy.
        def last_pickups
          last_pickups = []
          %w{meta stocks}.each do |queue_name|
            begin
              response = get "/queues/#{queue_name}/last_pick_up"
              queue_xml = response.parsed_response.css('queue').first
              last_pickups << Elibri::ApiClient::ApiAdapters::V1::Queue.build_from_xml(self, queue_xml)
            rescue NoRecentlyPickedUpQueues # Ignoruj błędy o braku ostatnich pickupów.
            end
          end  
          
          last_pickups
        end


        private

          # http://api.elibri.com.pl:80/api/v1
          def full_api_uri
            @host_uri + URI_PREFIX 
          end


          def get(request_uri, options = {})
            options.merge!({:digest_auth => @auth})
            request_uri = normalise_request_uri(request_uri)

            response = self.class.get(request_uri, options)
            raise_if_error_present_in response
            response
          end


          def post(request_uri, options = {})
            options.merge!({:digest_auth => @auth})
            request_uri = normalise_request_uri(request_uri)

            response = self.class.post(request_uri, options)
            raise_if_error_present_in response
            response
          end


          def normalise_request_uri(request_uri)
            if request_uri.start_with? 'http://'
              request_uri
            elsif !request_uri.start_with? '/'
              full_api_uri + '/' + request_uri
            else
              full_api_uri + request_uri
            end
          end


          def raise_if_error_present_in(response)
            raise Unauthorized, 'Bad login or password' if response.code == 401

            response_xml = response.parsed_response
            if response_xml && !response_xml.css('error').empty?
              error_id = response_xml.css('error').first['id']
              error_message = response_xml.css('error message').first.text

              # Rozpoznajemy ten kod błędu i możemy rzucić określoną klasą wyjątku:
              if exception_class = EXCEPTION_CLASSES[error_id.to_s]
                raise exception_class, error_message
              else
                # Jakiś nieznany błąd - rzucamy chociaż stringiem
                raise UnknownError, "ELIBRI_API ERROR #{error_id}: #{error_message}"
              end
            end
          end

      end

    end
  end
end
