require 'delegate'
require 'enumerator'

module HTML5lib
  module Filters
    class Base < SimpleDelegator
      include Enumerable
    end
  end
end
