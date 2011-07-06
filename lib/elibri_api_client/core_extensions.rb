

# HTTParty ma parsowac XML za pomoca Nokogiri. CRACK jest zbyt prosty do naszych zastosowan.
module HTTParty
  class Parser

    def xml
      @parsed_xml ||= Nokogiri::XML(body)
    end

  end
end


# Ukradzione z ActiveSupport:
class Object
  def blank?
    respond_to?(:empty?) ? empty? : !self
  end

  def present?
    !blank?
  end

  def presence
    self if present?
  end
end

class NilClass
  def blank?
    true
  end
end

class FalseClass
  def blank?
    true
  end
end

class TrueClass
  def blank?
    false
  end
end


class String
  def blank?
    self !~ /\S/
  end
end


class Numeric #:nodoc:
  def blank?
    false
  end
end
