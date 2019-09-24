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
        # debug_output $stderr
        #++

        def initialize(host_uri, login, password, onix_dialect) #:nodoc:
          @host_uri = host_uri
          @onix_dialect = onix_dialect
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
          resp = get '/queues'

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


        # Zwroc liste dostepnych wydawnictw - instancje Elibri::ApiClient::ApiAdapters::V1::Publisher
        # call-seq:
        #   publishers -> array
        #
        def publishers
          get_publishers_from_url('/publishers')
        end

        def pdw_publishers
          get_publishers_from_url('/publishers/pdw')
        end

        def olesiejuk_publishers
          get_publishers_from_url('/publishers/olesiejuk')
        end

        def virtualo_publishers
          get_publishers_from_url('/publishers/virtualo')
        end


        def remove_from_queue(queue_name, record_reference)
          resp = post "/queues/#{queue_name}/remove/#{record_reference}", :body => ' '
          return true
        end

        def add_to_queue(queue_name, record_reference)
          resp = post "/queues/#{queue_name}/add/#{record_reference}", :body => ' '
          return true
        end

        # params moze przyjac {:testing => 1, :count => 100, :offset => 100 (tylko przy testing=1)}
        def pop_from_queue(queue_name, params = {})
          params[:testing] = 1 if params[:testing]
          params = ' ' if params.empty?
          response = post "/queues/#{queue_name}/pop", :body => params, :headers => {"X-eLibri-API-ONIX-dialect" => @onix_dialect}

          return nil unless response.headers["x-elibri-api-pop-products-count"].to_i > 0
          Elibri::ApiClient::ApiAdapters::V1::QueuePop.new(
            :queue_name => response.headers["x-elibri-api-pop-queue-name"],
            :popped_products_count => response.headers["x-elibri-api-pop-products-count"],
            :created_at => response.headers["x-elibri-api-pop-created-at"],
            :xml => response.body
          )
        end


        def last_pop_from_queue(queue_name)
          response = get "/queues/#{queue_name}/last_pop", :headers => {"X-eLibri-API-ONIX-dialect" => @onix_dialect}
          Elibri::ApiClient::ApiAdapters::V1::QueuePop.new(
            :queue_name => response.headers["x-elibri-api-pop-queue-name"],
            :popped_products_count => response.headers["x-elibri-api-pop-products-count"],
            :created_at => response.headers["x-elibri-api-pop-created-at"],
            :xml => response.body
          )
        rescue Exceptions::NoRecentlyPoppedData # Ignoruj bledy o braku ostatnich POPow.
          return nil
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
        def onix_xml_for_product(product_or_rr, full_message = false) #:nodoc:
          if product_or_rr.kind_of? Elibri::ApiClient::ApiAdapters::V1::Product
            rr = product_or_rr.record_reference
          else
            rr = product_or_rr
          end
          resp = get "/products/#{rr}", :headers => {"X-eLibri-API-ONIX-dialect" => @onix_dialect}
          if full_message
            resp.parsed_response
          else
            resp.parsed_response.css('Product').first
          end
        end

        def get_product(product_or_rr)
          Elibri::ONIX::Release_3_0::Product.new(onix_xml_for_product(product_or_rr, false))
        end

        def get_onix_message_with_product(product_or_rr)
          Elibri::ONIX::Release_3_0::ONIXMessage.new(onix_xml_for_product(product_or_rr, true))
        end


        private

          # http://www.elibri.com.pl:80/api/v1
          def full_api_uri
            @host_uri + URI_PREFIX 
          end

          def get_publishers_from_url(url)
            resp = get(url)

            Array.new.tap do |publishers|
              resp.parsed_response.css('publisher').each do |publisher_xml|
                publisher = Elibri::ApiClient::ApiAdapters::V1::Publisher.build_from_xml(self, publisher_xml)
                publishers << publisher
              end
            end
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
