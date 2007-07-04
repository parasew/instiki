require 'html5/filters/base'

module HTML5
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
              # replace charset with actual encoding
              token[:data].each_with_index do |(name,value),index|
                if name == 'charset'
                  token[:data][index][1]=@encoding
                  meta_found = true
                end
              end

              # replace charset with actual encoding
              has_http_equiv_content_type = false
              content_index = -1
              token[:data].each_with_index do |(name,value),i|
                if name.downcase == 'charset'
                  token[:data][i] = ['charset', @encoding]
                  meta_found = true
                  break
                elsif name == 'http-equiv' and value.downcase == 'content-type'
                  has_http_equiv_content_type = true
                elsif name == 'content'
                  content_index = i
                end
              end

              if not meta_found
                if has_http_equiv_content_type and content_index >= 0
                  token[:data][content_index][1] =
                    'text/html; charset=%s' % @encoding
                  meta_found = true
                end
              end

            elsif token[:name].downcase == "head" and not meta_found
              # insert meta into empty head
              yield(:type => :StartTag, :name => "head", :data => token[:data])
              yield(:type => :EmptyTag, :name => "meta",
                    :data => [["charset", @encoding]])
              yield(:type => :EndTag, :name => "head")
              meta_found = true
              next
            end

          when :EndTag
            if token[:name].downcase == "head" and pending.any?
              # insert meta into head (if necessary) and flush pending queue
              yield pending.shift
              yield(:type => :EmptyTag, :name => "meta",
                    :data => [["charset", @encoding]]) if not meta_found
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
