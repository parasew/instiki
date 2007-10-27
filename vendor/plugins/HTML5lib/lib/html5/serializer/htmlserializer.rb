require 'html5/constants'

module HTML5

  class HTMLSerializer

    def self.serialize(stream, options = {})
      new(options).serialize(stream, options[:encoding])
    end

    def escape(string)
      string.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
    end
 
    def initialize(options={})
      @quote_attr_values           = false
      @quote_char                  = '"'
      @use_best_quote_char         = true
      @minimize_boolean_attributes = true

      @use_trailing_solidus          = false
      @space_before_trailing_solidus = true
      @escape_lt_in_attrs            = false
      @escape_rcdata                 = false

      @omit_optional_tags = true
      @sanitize           = false

      @strip_whitespace = false

      @inject_meta_charset = true

      options.each do |name, value|
        next unless instance_variables.include?("@#{name}")
        @use_best_quote_char = false if name.to_s == 'quote_char'
        instance_variable_set("@#{name}", value)
      end

      @errors = []
    end

    def serialize(treewalker, encoding=nil)
      in_cdata = false
      @errors = []

      if encoding and @inject_meta_charset
        require 'html5/filters/inject_meta_charset'
        treewalker = Filters::InjectMetaCharset.new(treewalker, encoding)
      end

      if @strip_whitespace
        require 'html5/filters/whitespace'
        treewalker = Filters::WhitespaceFilter.new(treewalker)
      end

      if @sanitize
        require 'html5/filters/sanitizer'
        treewalker = Filters::HTMLSanitizeFilter.new(treewalker)
      end

      if @omit_optional_tags
        require 'html5/filters/optionaltags'
        treewalker = Filters::OptionalTagFilter.new(treewalker)
      end

      result = []
      treewalker.each do |token|
        type = token[:type]
        if type == :Doctype
          doctype = "<!DOCTYPE %s>" % token[:name]
          result << doctype

        elsif [:Characters, :SpaceCharacters].include? type
          if type == :SpaceCharacters or in_cdata
            if in_cdata and token[:data].include?("</")
              serialize_error("Unexpected </ in CDATA")
            end
            result << token[:data]
          else
            result << escape(token[:data])
          end

        elsif [:StartTag, :EmptyTag].include? type
          name = token[:name]
          if RCDATA_ELEMENTS.include?(name) and not @escape_rcdata
            in_cdata = true
          elsif in_cdata
            serialize_error(_("Unexpected child element of a CDATA element"))
          end
          attributes = []
          for k,v in attrs = token[:data].to_a.sort
            attributes << ' '

            attributes << k
            if not @minimize_boolean_attributes or \
                (!(BOOLEAN_ATTRIBUTES[name]||[]).include?(k) \
                and !BOOLEAN_ATTRIBUTES[:global].include?(k))
              attributes << "="
              if @quote_attr_values or v.empty?
                quote_attr = true
              else
                quote_attr = (SPACE_CHARACTERS + %w(< > " ')).any? {|c| v.include?(c)}
              end
              v = v.gsub("&", "&amp;")
              v = v.gsub("<", "&lt;") if @escape_lt_in_attrs
              if quote_attr
                quote_char = @quote_char
                if @use_best_quote_char
                  if v.index("'") and !v.index('"')
                    quote_char = '"'
                  elsif v.index('"') and !v.index("'")
                    quote_char = "'"
                  end
                end
                if quote_char == "'"
                  v = v.gsub("'", "&#39;")
                else
                  v = v.gsub('"', "&quot;")
                end
                attributes << quote_char << v << quote_char
              else
                attributes << v
              end
            end
          end
          if VOID_ELEMENTS.include?(name) and @use_trailing_solidus
            if @space_before_trailing_solidus
              attributes << " /"
            else
              attributes << "/"
            end
          end
          result << "<%s%s>" % [name, attributes.join('')]

        elsif type == :EndTag
          name = token[:name]
          if RCDATA_ELEMENTS.include?(name)
            in_cdata = false
          elsif in_cdata
            serialize_error(_("Unexpected child element of a CDATA element"))
          end
          end_tag = "</#{name}>"
          result << end_tag

        elsif type == :Comment
          data = token[:data]
          serialize_error("Comment contains --") if data.index("--")
          comment = "<!--%s-->" % token[:data]
          result << comment

        else
          serialize_error(token[:data])
        end
      end

      if encoding and encoding != 'utf-8'
        require 'iconv'
        Iconv.iconv(encoding, 'utf-8', result.join('')).first
      else
        result.join('')
      end
    end

    alias :render :serialize

    def serialize_error(data="XXX ERROR MESSAGE NEEDED")
      # XXX The idea is to make data mandatory.
      @errors.push(data)
      if @strict
        raise SerializeError
      end
    end

  end

  # Error in serialized tree
  class SerializeError < Exception
  end
end
