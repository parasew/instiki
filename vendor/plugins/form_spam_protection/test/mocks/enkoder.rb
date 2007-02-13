require File.join(File.dirname(__FILE__), '../../vendor/enkoder/lib/enkoder')

module ActionView
  module Helpers
    module TextHelper

      # Don't really enkode, because our tests can't eval Javascript
      def enkode( html, max_length=nil )
        "<code>#{html}</code>"
      end
      
    end
  end
end