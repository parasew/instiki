if RUBY_VERSION >= "2.0.0"
  module Gem

    class SourceList
      def search( *args ); []; end
      def each( &block ); end
    end
  end
end

