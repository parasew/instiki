require 'html5lib/filters/base'

module HTML5lib
  module Filters
    class InjectMetaCharset < Base
      def initialize(source, encoding)
        super(source)
        @encoding = encoding
      end

      def each
        state = :pre_head
        meta_found = @encoding.nil?
        pending = []

        __getobj__.each do |token|
          case token[:type]
          when :StartTag
            state = :in_head if token[:name].downcase == "head"

          when :EmptyTag
            if token[:name].downcase == "meta"
              if token[:data].any? {|name,value| name=='charset'}
                # replace charset with actual encoding
                attrs=Hash[*token[:data].flatten]
                attrs['charset'] = @encoding
                token[:data] = attrs.to_a.sort
                meta_found = true
              end

            elsif token[:name].downcase == "head" and not meta_found
              # insert meta into empty head
              yield({:type => :StartTag, :name => "head", :data => {}})
              yield({:type => :EmptyTag, :name => "meta",
                     :data => {"charset" => @encoding}})
              yield({:type => :EndTag, :name => "head"})
              meta_found = true
              next
            end

          when :EndTag
            if token[:name].downcase == "head" and pending.any?
              # insert meta into head (if necessary) and flush pending queue
              yield pending.shift
              yield({:type => :EmptyTag, :name => "meta",
                     :data => {"charset" => @encoding}}) if not meta_found
              yield pending.shift while pending.any?
              meta_found = true
              state = :post_head
            end
          end

          if state == :in_head
            pending << token
          else
            yield token
          end
        end
      end
    end
  end
end
