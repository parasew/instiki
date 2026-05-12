# Explicitly load lib/ at boot. lib/ is not on Zeitwerk's autoload path
# because the existing lib/ tree predates Zeitwerk's filename↔constant
# convention (multi-class files, acronym-collapsed names, monkey-patches
# without a new constant). Rather than rename ~25 files, we require each
# in dependency order here and let Zeitwerk manage app/ only.
#
# This runs after Rails framework boot, so files that reopen
# ActionController::Base etc. at load time work as expected.

# Make `require 'chunks/foo'` (and similar) inside lib/ files keep working
# without :: autoload_paths.
lib = Rails.root.join("lib").to_s
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

# Pure monkey-patch (reopens Logger — no new constant defined)
require "logging_stuff"
require "frozen_string_compat"

# Standalone utilities — no inter-lib dependencies at load time
require "instiki_errors"
require "sanitizer"
require "html_tokenizer"
require "node"
require "wiki_words"
require "uriencoder"
require "dnsbl_check"
require "caching_stuff"
require "xhtmldiff"

# Chunk system — base classes first, then subclasses, then engines
require "chunks/chunk"
require "chunks/wiki"
require "chunks/category"
require "chunks/include"
require "chunks/literal"
require "chunks/nowiki"
require "chunks/redirect"
require "chunks/tikz"
require "chunks/uri"
require "rdocsupport"
require "oldredcloth"
require "chunks/engines"

# Higher-level: depend on the chunk classes above
require "wiki_content"
require "page_renderer"
require "url_generator"
