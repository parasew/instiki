require 'delegate'
require 'enumerator'

module HTML5
  module Filters
    class Base < SimpleDelegator
      include Enumerable
    end
  end
end
