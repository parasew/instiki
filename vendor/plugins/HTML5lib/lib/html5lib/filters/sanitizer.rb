require 'html5lib/filters/base'
require 'html5lib/sanitizer'

module HTML5lib
  module Filters
    class HTMLSanitizeFilter < Base
      include HTMLSanitizeModule
      def each
        __getobj__.each do |token|
          yield(sanitize_token(token))
        end
      end
    end
  end
end
