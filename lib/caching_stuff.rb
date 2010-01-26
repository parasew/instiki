# based on http://pastie.org/49840
# override the fragment_cache_key method in actionpack/lib/action_controller/caching/fragments.rb
# to remove hostname in fragment caching
# so instead of caching different fragments for "example.com/posts/list" and 
# "www.example.com/posts/list", instead it will just use "posts/list"
module CachingStuff
  module ActionController
    module Caching
      module Fragments
        def fragment_cache_key(key)
          ActiveSupport::Cache.expand_cache_key(key.is_a?(Hash) ? url_for(key.merge(:host=>"")).split(":///").last : key.split('/')[1..-1].join('/').gsub(/\?format=.*/,''), :views)
        end
      end
    end
  end
end

ActionController::Base.class_eval do
  include CachingStuff::ActionController::Caching::Fragments
end
