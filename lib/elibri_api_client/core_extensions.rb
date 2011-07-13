

# HTTParty ma parsowac XML za pomoca Nokogiri. CRACK jest zbyt prosty do naszych zastosowan.
module HTTParty #:nodoc:all
  class Parser

    def xml
      @parsed_xml ||= Nokogiri::XML(body)
    end

  end
end


