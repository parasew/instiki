# 
# This temporary test driver tracks progress on getting HTML5lib working
# on Ruby 1.9.  Prereqs of Hoe, Hpricot, and UniversalDetector will be
# required to complete this.
#
# Once all the tests pass, this file should be deleted
#

require 'test/test_cli'

# requires UniversalDetector
# require 'test/test_encoding'

require 'test/test_input_stream'

require 'test/test_lxp'

require 'test/test_parser'

# warning: method redefined; discarding old test
# warning: instance variable @expanded_name not initialized
# SimpleDelegator.class
# require 'test/test_sanitizer'

require 'test/test_serializer'

require 'test/test_sniffer'

require 'test/test_stream'

# warning: shadowing outer local variable - tokens
# require 'test/test_tokenizer'

# requires hpricot
# require 'test/test_treewalkers'

# warning: instance variable @delegate_sd_obj not initialized
# require 'test/test_validator'
