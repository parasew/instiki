require 'html5/filters/base'
require 'html5/sanitizer'

module HTML5
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
