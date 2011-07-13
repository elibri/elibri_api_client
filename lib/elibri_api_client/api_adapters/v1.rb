require 'elibri_api_client/api_adapters/v1_helpers'

module Elibri
  class ApiClient
    module ApiAdapters

      # Adapter dla 1 wersji API. Instancje odpowiedniego adaptera tworzy klasa Elibri::ApiClient - nie
      # robimy tego recznie.
      class V1
        URI_PREFIX = '/api/v1'

        include HTTParty
        #--
        #debug_output $stderr
        #++

        def initialize(host_uri, login, password) #:nodoc:
          @host_uri = host_uri
          @auth = {:username => login, :password => password}
        end


        # Wypelnij wszystkie kolejki oczekujace, wszystkimi dostepnymi danymi. Przydatne przy wykonywaniu
        # pelnej synchronizacji pomiedzy nasza aplikacja a Elibri.
        # call-seq:
        #   refill_all_queues! -> true
        #
        def refill_all_queues!
          # Dla POST musi byc jakies 'body' requestu, bo serwery czesto rzucaja wyjatkami (WEBrick w szczegolnosci).
          post '/queues/refill_all', :body => ' '
          true
        end


        # Zwroc liste kolejek z oczekujacymi danymi - instancje Elibri::ApiClient::ApiAdapters::V1::Queue
        # call-seq:
        #   pending_queues -> array
        #
        def pending_queues
          resp = get '/queues/pending_data'

          Array.new.tap do |pending_queues|
            resp.parsed_response.css('queue').each do |queue_xml|
              queue = Elibri::ApiClient::ApiAdapters::V1::Queue.build_from_xml(self, queue_xml)
              pending_queues << queue if queue.products_count.nonzero?
            end  
          end
        end


        # Czy sa jakies oczekujace dane w Elibri?
        # call-seq:
        #   pending_data? -> true or false
        #
        def pending_data?
          !pending_queues.empty?
        end


        # Ostatnio utworzone nazwane kolejki. Gdy wysypie nam sie aplikacja, mozna przegladac ostatnie pickupy
        # i ponownie pobierac z nich dane. Zwraca instance Elibri::ApiClient::ApiAdapters::V1::Queue
        # call-seq:
        #   last_pickups -> array
        #
        def last_pickups
          Array.new.tap do |last_pickups|
            %w{meta stocks}.each do |queue_name|
              begin
                response = get "/queues/#{queue_name}/last_pick_up"
                queue_xml = response.parsed_response.css('queue').first
                last_pickups << Elibri::ApiClient::ApiAdapters::V1::Queue.build_from_xml(self, queue_xml)
              rescue Exceptions::NoRecentlyPickedUpQueues # Ignoruj bledy o braku ostatnich pickupow.
              end
            end  
          end
        end


        # Zwroc liste dostepnych wydawnictw - instancje Elibri::ApiClient::ApiAdapters::V1::Publisher
        # call-seq:
        #   publishers -> array
        #
        def publishers
          resp = get '/publishers'

          Array.new.tap do |publishers|
            resp.parsed_response.css('publisher').each do |publisher_xml|
              publisher = Elibri::ApiClient::ApiAdapters::V1::Publisher.build_from_xml(self, publisher_xml)
              publishers << publisher
            end  
          end
        end


        # Utworz z danych oczekujacych w kolejce np. 'pending_meta', kolejke nazwana.
        # Tylko z kolejek nazwanych mozna pobierac dane. Jako argument przyjmuje nazwe kolejki (np. 'pending_meta')
        # lub odpowiednia instancje Elibri::ApiClient::ApiAdapters::V1::Queue.
        def pick_up_queue!(queue) #:nodoc:
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


        def each_page_in_queue(queue, &block) #:nodoc:
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


        # Trawersuj kolekcje produktow w nazwanej kolejce. Instancje nazwanej kolejki nalezy przekazac
        # jako argument metody.
        def each_product_onix_in_queue(queue, &block) #:nodoc:
          raise 'Need a Elibri::ApiClient::ApiAdapters::V1::Queue instance' unless queue.kind_of? Elibri::ApiClient::ApiAdapters::V1::Queue

          product_no = 1
          each_page_in_queue(queue) do |products_page_xml, page_no|
            products_page_xml.css('Product').each do |product_xml|
              block.call(product_xml, product_no)
              product_no += 1
            end  
          end
        end


        # Zwroc liste produktow dla podanego wydawnictwa.
        def products_for_publisher(publisher) #:nodoc:
          raise 'Need a Elibri::ApiClient::ApiAdapters::V1::Publisher instance' unless publisher.kind_of? Elibri::ApiClient::ApiAdapters::V1::Publisher
          resp = get "/publishers/#{publisher.publisher_id}/products"

          Array.new.tap do |products|
            resp.parsed_response.css('product').each do |product_xml|
              product = Elibri::ApiClient::ApiAdapters::V1::Product.build_from_xml(self, publisher, product_xml)
              products << product
            end  
          end
        end


        # Zwroc ONIX dla konkretnego produktu.
        def onix_xml_for_product(product) #:nodoc:
          raise 'Need a Elibri::ApiClient::ApiAdapters::V1::Product instance' unless product.kind_of? Elibri::ApiClient::ApiAdapters::V1::Product
          resp = get "/products/#{product.record_reference}"
          resp.parsed_response.css('Product').first
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


          # Jesli Elibri zwoci jakis blad, to rzucamy odpowiednim wyjatkiem.
          def raise_if_error_present_in(response)
            raise Exceptions::Unauthorized, 'Bad login or password' if response.code == 401

            response_xml = response.parsed_response
            if response_xml && !response_xml.css('error').empty?
              error_id = response_xml.css('error').first['id']
              error_message = response_xml.css('error message').first.text

              # Rozpoznajemy ten kod bledu i mozemy rzucic okreslona klasa wyjatku:
              if exception_class = EXCEPTION_CLASSES[error_id.to_s]
                raise exception_class, error_message
              else
                # Jakis nieznany blad - rzucamy chociaz stringiem
                raise Exceptions::UnknownError, "ELIBRI_API ERROR #{error_id}: #{error_message}"
              end
            end
          end

      end

    end
  end
end
