# HTML 5 conformance checker
# 
# Warning: this module is experimental, incomplete, and subject to removal at any time.
# 
# Usage:
# >>> from html5lib.html5parser import HTMLParser
# >>> from html5lib.filters.validator import HTMLConformanceChecker
# >>> p = HTMLParser(tokenizer=HTMLConformanceChecker)
# >>> p.parse('<!doctype html>\n<html foo=bar></html>')
# <<class 'html5lib.treebuilders.simpletree.Document'> nil>
# >>> p.errors
# [((2, 14), 'unknown-attribute', {'attributeName' => u'foo', 'tagName' => u'html'})]

require 'html5/constants'
require 'html5/filters/base'
require 'html5/filters/iso639codes'
require 'html5/filters/rfc3987'
require 'html5/filters/rfc2046'

def _(str); str; end

class String
  # lifted from rails
  def underscore()
     self.gsub(/::/, '/').
       gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
       gsub(/([a-z\d])([A-Z])/,'\1_\2').
       tr("-", "_").
       downcase
   end
end

HTML5::E.update({
  "unknown-start-tag" =>
    _("Unknown start tag <%(tagName)>."),
  "unknown-attribute" =>
    _("Unknown '%(attributeName)' attribute on <%(tagName)>."),
  "missing-required-attribute" =>
    _("The '%(attributeName)' attribute is required on <%(tagName)>."),
  "unknown-input-type" =>
    _("Illegal value for attribute on <input type='%(inputType)'>."),
  "attribute-not-allowed-on-this-input-type" =>
    _("The '%(attributeName)' attribute is not allowed on <input type=%(inputType)>."),
  "deprecated-attribute" =>
    _("This attribute is deprecated: '%(attributeName)' attribute on <%(tagName)>."),
  "duplicate-value-in-token-list" =>
    _("Duplicate value in token list: '%(attributeValue)' in '%(attributeName)' attribute on <%(tagName)>."),
  "invalid-attribute-value" =>
    _("Invalid attribute value: '%(attributeName)' attribute on <%(tagName)>."),
  "space-in-id" =>
    _("Whitespace is not allowed here: '%(attributeName)' attribute on <%(tagName)>."),
  "duplicate-id" =>
    _("This ID was already defined earlier: 'id' attribute on <%(tagName)>."),
  "attribute-value-can-not-be-blank" =>
    _("This value can not be blank: '%(attributeName)' attribute on <%(tagName)>."),
  "id-does-not-exist" =>
    _("This value refers to a non-existent ID: '%(attributeName)' attribute on <%(tagName)>."),
  "invalid-enumerated-value" =>
    _("Value must be one of %(enumeratedValues): '%(attributeName)' attribute on <%tagName)>."),
  "invalid-boolean-value" =>
    _("Value must be one of %(enumeratedValues): '%(attributeName)' attribute on <%tagName)>."),
  "contextmenu-must-point-to-menu" =>
    _("The contextmenu attribute must point to an ID defined on a <menu> element."),
  "invalid-lang-code" =>
    _("Invalid language code: '%(attributeName)' attibute on <%(tagName)>."),
  "invalid-integer-value" =>
    _("Value must be an integer: '%(attributeName)' attribute on <%tagName)>."),
  "invalid-root-namespace" =>
    _("Root namespace must be 'http://www.w3.org/1999/xhtml', or omitted."),
  "invalid-browsing-context" =>
    _("Value must be one of ('_self', '_parent', '_top'), or a name that does not start with '_' => '%(attributeName)' attribute on <%(tagName)>."),
  "invalid-tag-uri" =>
    _("Invalid URI: '%(attributeName)' attribute on <%(tagName)>."),
  "invalid-urn" =>
    _("Invalid URN: '%(attributeName)' attribute on <%(tagName)>."),
  "invalid-uri-char" =>
    _("Illegal character in URI: '%(attributeName)' attribute on <%(tagName)>."),
  "uri-not-iri" =>
    _("Expected a URI but found an IRI: '%(attributeName)' attribute on <%(tagName)>."),
  "invalid-uri" =>
    _("Invalid URI: '%(attributeName)' attribute on <%(tagName)>."),
  "invalid-http-or-ftp-uri" =>
    _("Invalid URI: '%(attributeName)' attribute on <%(tagName)>."),
  "invalid-scheme" =>
    _("Unregistered URI scheme: '%(attributeName)' attribute on <%(tagName)>."),
  "invalid-rel" =>
    _("Invalid link relation: '%(attributeName)' attribute on <%(tagName)>."),
  "invalid-mime-type" =>
    _("Invalid MIME type: '%(attributeName)' attribute on <%(tagName)>."),
})


class HTMLConformanceChecker < HTML5::Filters::Base

  @@global_attributes = %w[class contenteditable contextmenu dir
    draggable id irrelevant lang ref tabindex template
    title onabort onbeforeunload onblur onchange onclick
    oncontextmenu ondblclick ondrag ondragend ondragenter
    ondragleave ondragover ondragstart ondrop onerror
    onfocus onkeydown onkeypress onkeyup onload onmessage
    onmousedown onmousemove onmouseout onmouseover onmouseup
    onmousewheel onresize onscroll onselect onsubmit onunload]
  # XXX lang in HTML only, xml:lang in XHTML only
  # XXX validate ref, template

  @@allowed_attribute_map = {
    'html'         => %w[xmlns],
    'head'         => [],
    'title'        => [],
    'base'         => %w[href target],
    'link'         => %w[href rel media hreflang type],
    'meta'         => %w[name http-equiv content charset], # XXX charset in HTML only
    'style'        => %w[media type scoped],
    'body'         => [],
    'section'      => [],
    'nav'          => [],
    'article'      => [],
    'blockquote'   => %w[cite],
    'aside'        => [],
    'h1'           => [],
    'h2'           => [],
    'h3'           => [],
    'h4'           => [],
    'h5'           => [],
    'h6'           => [],
    'header'       => [],
    'footer'       => [],
    'address'      => [],
    'p'            => [],
    'hr'           => [],
    'br'           => [],
    'dialog'       => [],
    'pre'          => [],
    'ol'           => %w[start],
    'ul'           => [],
    'li'           => %w[value], # XXX depends on parent
    'dl'           => [],
    'dt'           => [],
    'dd'           => [],
    'a'            => %w[href target ping rel media hreflang type],
    'q'            => %w[cite],
    'cite'         => [],
    'em'           => [],
    'strong'       => [],
    'small'        => [],
    'm'            => [],
    'dfn'          => [],
    'abbr'         => [],
    'time'         => %w[datetime],
    'meter'        => %w[value min low high max optimum],
    'progress'     => %w[value max],
    'code'         => [],
    'var'          => [],
    'samp'         => [],
    'kbd'          => [],
    'sup'          => [],
    'sub'          => [],
    'span'         => [],
    'i'            => [],
    'b'            => [],
    'bdo'          => [],
    'ins'          => %w[cite datetime],
    'del'          => %w[cite datetime],
    'figure'       => [],
    'img'          => %w[alt src usemap ismap height width], # XXX ismap depends on parent
    'iframe'       => %w[src],
    # <embed> handled separately
    'object'       => %w[data type usemap height width],
    'param'        => %w[name value],
    'video'        => %w[src autoplay start loopstart loopend end loopcount controls],
    'audio'        => %w[src autoplay start loopstart loopend end loopcount controls],
    'source'       => %w[src type media],
    'canvas'       => %w[height width],
    'map'          => [],
    'area'         => %w[alt coords shape href target ping rel media hreflang type],
    'table'        => [],
    'caption'      => [],
    'colgroup'     => %w[span], # XXX only if element contains no <col> elements
    'col'          => %w[span],
    'tbody'        => [],
    'thead'        => [],
    'tfoot'        => [],
    'tr'           => [],
    'td'           => %w[colspan rowspan],
    'th'           => %w[colspan rowspan scope],
    # all possible <input> attributes are listed here but <input> is really handled separately
    'input'        => %w[accept accesskey action alt autocomplete autofocus checked
                         disabled enctype form inputmode list maxlength method min 
                         max name pattern step readonly replace required size src
                         tabindex target template value
    ],
    'form'         => %w[action method enctype accept name onsubmit onreset accept-charset
                         data replace
    ],
    'button'       => %w[action enctype method replace template name value type disabled form autofocus], # XXX may need matrix of acceptable attributes based on value of type attribute (like input)
    'select'       => %w[name size multiple disabled data accesskey form autofocus],
    'optgroup'     => %w[disabled label],
    'option'       => %w[selected disabled label value],
    'textarea'     => %w[maxlength name rows cols disabled readonly required form autofocus wrap accept],
    'label'        => %w[for accesskey form],
    'fieldset'     => %w[disabled form],
    'output'       => %w[form name for onforminput onformchange],
    'datalist'     => %w[data],
     # XXX repetition model for repeating form controls
    'script'       => %w[src defer async type],
    'noscript'     => [],
    'noembed'      => [],
    'event-source' => %w[src],
    'details'      => %w[open],
    'datagrid'     => %w[multiple disabled],
    'command'      => %w[type label icon hidden disabled checked radiogroup default],
    'menu'         => %w[type label autosubmit],
    'datatemplate' => [],
    'rule'         => [],
    'nest'         => [],
    'legend'       => [],
    'div'          => [],
    'font'         => %w[style]
  }

  @@required_attribute_map = {
    'link'   => %w[href rel],
    'bdo'    => %w[dir],
    'img'    => %w[src],
    'embed'  => %w[src],
    'object' => [], # XXX one of 'data' or 'type' is required
    'param'  => %w[name value],
    'source' => %w[src],
    'map'    => %w[id]
  }

  @@input_type_allowed_attribute_map = {
    'text'           => %w[accesskey autocomplete autofocus disabled form inputmode list maxlength name pattern readonly required size tabindex value],
    'password'       => %w[accesskey autocomplete autofocus disabled form inputmode maxlength name pattern readonly required size tabindex value],
    'checkbox'       => %w[accesskey autofocus checked disabled form name required tabindex value],
    'radio'          => %w[accesskey autofocus checked disabled form name required tabindex value],
    'button'         => %w[accesskey autofocus disabled form name tabindex value],
    'submit'         => %w[accesskey action autofocus disabled enctype form method name replace tabindex target value],
    'reset'          => %w[accesskey autofocus disabled form name tabindex value],
    'add'            => %w[accesskey autofocus disabled form name tabindex template value],
    'remove'         => %w[accesskey autofocus disabled form name tabindex value],
    'move-up'        => %w[accesskey autofocus disabled form name tabindex value],
    'move-down'      => %w[accesskey autofocus disabled form name tabindex value],
    'file'           => %w[accept accesskey autofocus disabled form min max name required tabindex],
    'hidden'         => %w[disabled form name value],
    'image'          => %w[accesskey action alt autofocus disabled enctype form method name replace src tabindex target],
    'datetime'       => %w[accesskey autocomplete autofocus disabled form list min max name step readonly required tabindex value],
    'datetime-local' => %w[accesskey autocomplete autofocus disabled form list min max name step readonly required tabindex value],
    'date'           => %w[accesskey autocomplete autofocus disabled form list min max name step readonly required tabindex value],
    'month'          => %w[accesskey autocomplete autofocus disabled form list min max name step readonly required tabindex value],
    'week'           => %w[accesskey autocomplete autofocus disabled form list min max name step readonly required tabindex value],
    'time'           => %w[accesskey autocomplete autofocus disabled form list min max name step readonly required tabindex value],
    'number'         => %w[accesskey autocomplete autofocus disabled form list min max name step readonly required tabindex value],
    'range'          => %w[accesskey autocomplete autofocus disabled form list min max name step readonly required tabindex value],
    'email'          => %w[accesskey autocomplete autofocus disabled form inputmode list maxlength name pattern readonly required tabindex value],
    'url'            => %w[accesskey autocomplete autofocus disabled form inputmode list maxlength name pattern readonly required tabindex value],
  }

  @@input_type_deprecated_attribute_map = {
    'text'     => ['size'],
    'password' => ['size']
  }

  @@link_rel_values = %w[alternate archive archives author contact feed first begin start help icon index top contents toc last end license copyright next pingback prefetch prev previous search stylesheet sidebar tag up]
  @@a_rel_values    = %w[alternate archive archives author contact feed first begin start help index top contents toc last end license copyright next prev previous search sidebar tag up bookmark external nofollow]

  def initialize(stream, *args)
    super(HTML5::HTMLTokenizer.new(stream, *args))
    @things_that_define_an_id    = []
    @things_that_point_to_an_id  = []
    @ids_we_have_known_and_loved = []
  end
  
  def each
    __getobj__.each do |token|
      method = "validate_#{token.fetch(:type, '-').to_s.underscore}_#{token.fetch(:name, '-').to_s.underscore}"
      if respond_to?(method)
        send(method, token){|t| yield t }
      else
        method = "validate_#{token.fetch(:type, '-').to_s.underscore}"
        if respond_to?(method)
          send(method, token) do |t|
            yield t
          end
        end
      end
      yield token
    end
    eof do |t|
      yield t
    end
  end

  ##########################################################################
  # Start tag validation
  ##########################################################################

  def validate_start_tag(token)
    check_unknown_start_tag(token){|t| yield t}
    check_start_tag_required_attributes(token) do |t|
      yield t
    end
    check_start_tag_unknown_attributes(token) do |t|
      yield t
    end
    check_attribute_values(token) do |t|
      yield t
    end
  end

  def validate_start_tag_embed(token)
    check_start_tag_required_attributes(token) do |t|
      yield t
    end
    check_attribute_values(token) do |t|
      yield t
    end
    # spec says "any attributes w/o namespace"
    # so don't call check_start_tag_unknown_attributes
  end

  def validate_start_tag_input(token)
    check_attribute_values(token) do |t|
      yield t
    end
    attr_dict = Hash[*token[:data].collect{|(name, value)| [name.downcase, value]}.flatten]
    input_type = attr_dict.fetch('type', "text")
    if !@@input_type_allowed_attribute_map.keys().include?(input_type)
      yield({:type => "ParseError",
           :data => "unknown-input-type",
           :datavars => {:attrValue => input_type}})
    end
    allowed_attributes = @@input_type_allowed_attribute_map.fetch(input_type, [])
    attr_dict.each do |attr_name, attr_value|
      if !@@allowed_attribute_map['input'].include?(attr_name)
        yield({:type => "ParseError",
             :data => "unknown-attribute",
             :datavars => {"tagName" => "input",
                  "attributeName" => attr_name}})
      elsif !allowed_attributes.include?(attr_name)
        yield({:type => "ParseError",
             :data => "attribute-not-allowed-on-this-input-type",
             :datavars => {"attributeName" => attr_name,
                  "inputType" => input_type}})
      end
      if @@input_type_deprecated_attribute_map.fetch(input_type, []).include?(attr_name)
        yield({:type => "ParseError",
             :data => "deprecated-attribute",
             :datavars => {"attributeName" => attr_name,
                  "inputType" => input_type}})
      end
    end
  end

  ##########################################################################
  # Start tag validation helpers
  ##########################################################################

  def check_unknown_start_tag(token)
    # check for recognized tag name
    name = (token[:name] || "").downcase
    if !@@allowed_attribute_map.keys.include?(name)
      yield({:type => "ParseError",
             :data => "unknown-start-tag",
             :datavars => {"tagName" => name}})
    end
  end

  def check_start_tag_required_attributes(token)
    # check for presence of required attributes
    name = (token[:name] || "").downcase
    if @@required_attribute_map.keys().include?(name)
      attrs_present = (token[:data] || []).collect{|t| t[0]}
      for attr_name in @@required_attribute_map[name]
        if !attrs_present.include?(attr_name)
          yield( {:type => "ParseError",
               :data => "missing-required-attribute",
               :datavars => {"tagName" => name,
                    "attributeName" => attr_name}})
        end
      end
    end
  end

  def check_start_tag_unknown_attributes(token)
    # check for recognized attribute names
    name = token[:name].downcase
    allowed_attributes = @@global_attributes | @@allowed_attribute_map.fetch(name, [])
    for attr_name, attr_value in token.fetch(:data, [])
      if !allowed_attributes.include?(attr_name.downcase())
        yield( {:type => "ParseError",
             :data => "unknown-attribute",
             :datavars => {"tagName" => name,
                  "attributeName" => attr_name}})
      end
    end
  end

  ##########################################################################
  # Attribute validation helpers
  ##########################################################################

#  def checkURI(token, tag_name, attr_name, attr_value)
#    is_valid, error_code = rfc3987.is_valid_uri(attr_value)
#    if not is_valid
#      yield {:type => "ParseError",
#           :data => error_code,
#           :datavars => {"tagName" => tag_name,
#                "attributeName" => attr_name}}
#      yield {:type => "ParseError",
#           :data => "invalid-attribute-value",
#           :datavars => {"tagName" => tag_name,
#                "attributeName" => attr_name}}

  def check_iri(token, tag_name, attr_name, attr_value)
    is_valid, error_code = is_valid_iri(attr_value)
    if !is_valid
      yield({:type => "ParseError",
             :data => error_code,
             :datavars => {"tagName" => tag_name,
                "attributeName" => attr_name}})
      yield({:type => "ParseError",
             :data => "invalid-attribute-value",
             :datavars => {"tagName" => tag_name,
                "attributeName" => attr_name}})
    end
  end

  def check_id(token, tag_name, attr_name, attr_value)
    if !attr_value || attr_value.length == 0
      yield({:type => "ParseError",
              :data => "attribute-value-can-not-be-blank",
              :datavars => {"tagName" => tag_name,
                "attributeName" => attr_name}})
    end
    attr_value.each_byte do |b|
      c = [b].pack('c*')
      if HTML5::SPACE_CHARACTERS.include?(c)
        yield( {:type => "ParseError",
             :data => "space-in-id",
             :datavars => {"tagName" => tag_name,
                  "attributeName" => attr_name}})
        yield( {:type => "ParseError",
             :data => "invalid-attribute-value",
             :datavars => {"tagName" => tag_name,
                  "attributeName" => attr_name}})
        break
      end
    end
  end

  def parse_token_list(value)
    valueList = []
    currentValue = ''
    (value + ' ').each_byte do |b|
      c = [b].pack('c*')
      if HTML5::SPACE_CHARACTERS.include?(c)
        if currentValue.length > 0
          valueList << currentValue
          currentValue = ''
        end
      else
        currentValue += c
      end
    end
    if currentValue.length > 0
      valueList << currentValue
    end
    valueList
  end

  def check_token_list(tag_name, attr_name, attr_value)
    # The "token" in the method name refers to tokens in an attribute value
    # i.e. http://www.whatwg.org/specs/web-apps/current-work/#set-of
    # but the "token" parameter refers to the token generated from
    # HTMLTokenizer.  Sorry for the confusion.
    value_list = parse_token_list(attr_value)
    value_dict = {}
    for current_value in value_list
      if value_dict.has_key?(current_value)
        yield({:type => "ParseError",
             :data => "duplicate-value-in-token-list",
             :datavars => {"tagName" => tag_name,
                  "attributeName" => attr_name,
                  "attributeValue" => current_value}})
        break
      end
      value_dict[current_value] = 1
    end
  end

  def check_enumerated_value(token, tag_name, attr_name, attr_value, enumerated_values)
    if !attr_value || attr_value.length == 0
      yield( {:type => "ParseError",
           :data => "attribute-value-can-not-be-blank",
           :datavars => {"tagName" => tag_name,
                "attributeName" => attr_name}})
      return
    end
    attr_value.downcase!
    if !enumerated_values.include?(attr_value)
      yield( {:type => "ParseError",
           :data => "invalid-enumerated-value",
           :datavars => {"tagName" => tag_name,
                "attribute_name" => attr_name,
                "enumeratedValues" => enumerated_values}})
      yield( {:type => "ParseError",
           :data => "invalid-attribute-value",
           :datavars => {"tagName" => tag_name,
                "attributeName" => attr_name}})
    end
  end

  def check_boolean(token, tag_name, attr_name, attr_value)
    enumerated_values = [attr_name, '']
    if !enumerated_values.include?(attr_value)
      yield( {:type => "ParseError",
           :data => "invalid-boolean-value",
           :datavars => {"tagName" => tag_name,
                "attributeName" => attr_name,
                "enumeratedValues" => enumerated_values}})
      yield( {:type => "ParseError",
           :data => "invalid-attribute-value",
           :datavars => {"tagName" => tag_name,
                "attributeName" => attr_name}})
    end
  end

  def check_integer(token, tag_name, attr_name, attr_value)
    sign = 1
    number_string = ''
    state = 'begin' # ('begin', 'initial-number', 'number', 'trailing-junk')
    error = {:type => "ParseError",
         :data => "invalid-integer-value",
         :datavars => {"tagName" => tag_name,
                "attributeName" => attr_name,
                "attributeValue" => attr_value}}
    attr_value.scan(/./) do |c|
      if state == 'begin'
        if HTML5::SPACE_CHARACTERS.include?(c)
          next
        elsif c == '-'
          sign  = -1
          state = 'initial-number'
        elsif HTML5::DIGITS.include?(c)
          number_string += c
          state = 'in-number'
        else
          yield error
          return
        end
      elsif state == 'initial-number'
        if !HTML5::DIGITS.include?(c)
          yield error
          return
        end
        number_string += c
        state = 'in-number'
      elsif state == 'in-number'
        if HTML5::DIGITS.include?(c)
          number_string += c
        else
          state = 'trailing-junk'
        end
      elsif state == 'trailing-junk'
        next
      end
    end
    if number_string.length == 0
      yield( {:type => "ParseError",
           :data => "attribute-value-can-not-be-blank",
           :datavars => {"tagName" => tag_name,
                "attributeName" => attr_name}})
    end
  end

  def check_floating_point_number(token, tag_name, attr_name, attr_value)
    # XXX
  end

  def check_browsing_context(token, tag_name, attr_name, attr_value)
    return if not attr_value
    return if attr_value[0] != ?_
    attr_value.downcase!
    return if ['_self', '_parent', '_top', '_blank'].include?(attr_value)
    yield({:type => "ParseError",
         :data => "invalid-browsing-context",
         :datavars => {"tagName" => tag_name,
              "attributeName" => attr_name}})
  end

  def check_lang_code(token, tag_name, attr_name, attr_value)
    return if !attr_value || attr_value == '' # blank is OK
    if not is_valid_lang_code(attr_value)
      yield( {:type => "ParseError",
           :data => "invalid-lang-code",
           :datavars => {"tagName" => tag_name,
                "attributeName" => attr_name,
                "attributeValue" => attr_value}})
    end
  end
  
  def check_mime_type(token, tag_name, attr_name, attr_value)
    # XXX needs tests
    if not attr_value
      yield( {:type => "ParseError",
           :data => "attribute-value-can-not-be-blank",
           :datavars => {"tagName" => tag_name,
                "attributeName" => attr_name}})
    end
    if not is_valid_mime_type(attr_value)
      yield( {:type => "ParseError",
           :data => "invalid-mime-type",
           :datavars => {"tagName" => tag_name,
                "attributeName" => attr_name,
                "attributeValue" => attr_value}})
    end
  end

  def check_media_query(token, tag_name, attr_name, attr_value)
    # XXX
  end

  def check_link_relation(token, tag_name, attr_name, attr_value)
    check_token_list(tag_name, attr_name, attr_value) do |t|
      yield t
    end
    value_list = parse_token_list(attr_value)
    allowed_values = tag_name == 'link' ? @@link_rel_values : @@a_rel_values
    for current_value in value_list
      if !allowed_values.include?(current_value)
        yield({:type => "ParseError",
             :data => "invalid-rel",
             :datavars => {"tagName" => tag_name,
                  "attributeName" => attr_name}})
      end
    end
  end

  def check_date_time(token, tag_name, attr_name, attr_value)
    # XXX
    state = 'begin' # ('begin', '...
#    for c in attr_value
#      if state == 'begin' =>
#        if SPACE_CHARACTERS.include?(c)
#          continue
#        elsif digits.include?(c)
#          state = ...
  end

  ##########################################################################
  # Attribute validation
  ##########################################################################

  def check_attribute_values(token)
    tag_name = token.fetch(:name, "")
    for attr_name, attr_value in token.fetch(:data, [])
      attr_name = attr_name.downcase
      method = "validate_attribute_value_#{tag_name.to_s.underscore}_#{attr_name.to_s.underscore}"
      if respond_to?(method)
        send(method, token, tag_name, attr_name, attr_value) do |t|
          yield t
        end
      else
        method = "validate_attribute_value_#{attr_name.to_s.underscore}"
        if respond_to?(method)
          send(method, token, tag_name, attr_name, attr_value) do |t|
            yield t
          end
        end
      end
    end
  end

  def validate_attribute_value_class(token, tag_name, attr_name, attr_value)
    check_token_list(tag_name, attr_name, attr_value) do |t|
      yield t
      yield( {:type => "ParseError",
           :data => "invalid-attribute-value",
           :datavars => {"tagName" => tag_name,
                "attributeName" => attr_name}})
    end
  end

  def validate_attribute_value_contenteditable(token, tag_name, attr_name, attr_value)
    check_enumerated_value(token, tag_name, attr_name, attr_value, ['true', 'false', '']) do |t|
      yield t
    end
  end

  def validate_attribute_value_dir(token, tag_name, attr_name, attr_value)
    check_enumerated_value(token, tag_name, attr_name, attr_value, ['ltr', 'rtl']) do |t|
      yield t
    end
  end

  def validate_attribute_value_draggable(token, tag_name, attr_name, attr_value)
    check_enumerated_value(token, tag_name, attr_name, attr_value, ['true', 'false']) do |t|
      yield t
    end
  end

  alias validate_attribute_value_irrelevant check_boolean
  alias validate_attribute_value_lang       check_lang_code

  def validate_attribute_value_contextmenu(token, tag_name, attr_name, attr_value)
    check_id(token, tag_name, attr_name, attr_value) do |t|
      yield t
    end
    @things_that_point_to_an_id << token
  end

  def validate_attribute_value_id(token, tag_name, attr_name, attr_value)
    # This method has side effects.  It adds 'token' to the list of
    # things that define an ID (@things_that_define_an_id) so that we can
    # later check 1) whether an ID is duplicated, and 2) whether all the
    # things that point to something else by ID (like <label for> or
    # <span contextmenu>) point to an ID that actually exists somewhere.
    check_id(token, tag_name, attr_name, attr_value) do |t|
      yield t
    end
    return if not attr_value
    if @ids_we_have_known_and_loved.include?(attr_value)
      yield( {:type => "ParseError",
           :data => "duplicate-id",
           :datavars => {"tagName" => tag_name}})
    end
    @ids_we_have_known_and_loved << attr_value
    @things_that_define_an_id << token
  end

  alias validate_attribute_value_tabindex check_integer

  def validate_attribute_value_ref(token, tag_name, attr_name, attr_value)
    # XXX
  end

  def validate_attribute_value_template(token, tag_name, attr_name, attr_value)
    # XXX
  end

  def validate_attribute_value_html_xmlns(token, tag_name, attr_name, attr_value)
    if attr_value != "http://www.w3.org/1999/xhtml"
      yield( {:type => "ParseError",
           :data => "invalid-root-namespace",
           :datavars => {"tagName" => tag_name,
                "attributeName" => attr_name}})
    end
  end

  alias validate_attribute_value_base_href       check_iri
  alias validate_attribute_value_base_target     check_browsing_context
  alias validate_attribute_value_link_href       check_iri
  alias validate_attribute_value_link_rel        check_link_relation
  alias validate_attribute_value_link_media      check_media_query
  alias validate_attribute_value_link_hreflang   check_lang_code
  alias validate_attribute_value_link_type       check_mime_type
  # XXX <meta> attributes
  alias validate_attribute_value_style_media     check_media_query
  alias validate_attribute_value_style_type      check_mime_type
  alias validate_attribute_value_style_scoped    check_boolean
  alias validate_attribute_value_blockquote_cite check_iri
  alias validate_attribute_value_ol_start        check_integer
  alias validate_attribute_value_li_value        check_integer
  # XXX need tests from here on
  alias validate_attribute_value_a_href          check_iri
  alias validate_attribute_value_a_target        check_browsing_context

  def validate_attribute_value_a_ping(token, tag_name, attr_name, attr_value)
    value_list = parse_token_list(attr_value)
    for current_value in value_list
      checkIRI(token, tag_name, attr_name, attr_value) do |t|
        yield t
      end
    end
  end

  alias validate_attribute_value_a_rel           check_link_relation
  alias validate_attribute_value_a_media         check_media_query
  alias validate_attribute_value_a_hreflang      check_lang_code
  alias validate_attribute_value_a_type          check_mime_type
  alias validate_attribute_value_q_cite          check_iri
  alias validate_attribute_value_time_datetime   check_date_time
  alias validate_attribute_value_meter_value     check_floating_point_number
  alias validate_attribute_value_meter_min       check_floating_point_number
  alias validate_attribute_value_meter_low       check_floating_point_number
  alias validate_attribute_value_meter_high      check_floating_point_number
  alias validate_attribute_value_meter_max       check_floating_point_number
  alias validate_attribute_value_meter_optimum   check_floating_point_number
  alias validate_attribute_value_progress_value  check_floating_point_number
  alias validate_attribute_value_progress_max    check_floating_point_number
  alias validate_attribute_value_ins_cite        check_iri
  alias validate_attribute_value_ins_datetime    check_date_time
  alias validate_attribute_value_del_cite        check_iri
  alias validate_attribute_value_del_datetime    check_date_time

  ##########################################################################
  # Whole document validation (IDs, etc.)
  ##########################################################################

  def eof
    for token in @things_that_point_to_an_id
      tag_name = token.fetch(:name, "").downcase
      attrs_dict = token[:data] # by now html5parser has "normalized" the attrs list into a dict.
                    # hooray for obscure side effects!
      attr_value = attrs_dict.fetch("contextmenu", "")
      if attr_value and (!@ids_we_have_known_and_loved.include?(attr_value))
        yield( {:type => "ParseError",
             :data => "id-does-not-exist",
             :datavars => {"tagName" => tag_name,
                  "attributeName" => "contextmenu",
                  "attributeValue" => attr_value}})
      else
        for ref_token in @things_that_define_an_id
          id = ref_token.fetch(:data, {}).fetch("id", "")
          if not id
            continue
          end
          if id == attr_value
            if ref_token.fetch(:name, "").downcase != "men"
              yield( {:type => "ParseError",
                   :data => "contextmenu-must-point-to-menu"})
            end
            break
          end
        end
      end
    end
  end
end
