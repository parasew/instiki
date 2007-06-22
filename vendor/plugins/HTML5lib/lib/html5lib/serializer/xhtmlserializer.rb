require 'html5lib/serializer/htmlserializer'

module HTML5lib

  class XHTMLSerializer < HTMLSerializer
    DEFAULTS = {
      :quote_attr_values => true,
      :minimize_boolean_attributes => false,
      :use_trailing_solidus => true,
      :escape_lt_in_attrs => true,
      :omit_optional_tags => false
    }

    def initialize(options={})
      super(DEFAULTS.clone.update(options))
    end
  end

end
