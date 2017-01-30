require 'instiki_errors'
require 'wiki_content'

# Miscellaneous monkey patches (here be dragons ...)     

require 'caching_stuff'     
require 'logging_stuff'

# Additional Mime-types 
mime_types = YAML.load_file(File.join(File.dirname(__FILE__), '../mime_types.yml'))
Rack::Mime::MIME_TYPES.merge!(mime_types)
