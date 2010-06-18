require 'webrick'
require 'stringio'
require 'rack/content_length'
require 'tempfile'

module Rack
  module Handler
    class WEBrick < ::WEBrick::HTTPServlet::AbstractServlet
      def self.run(app, options={})
        options[:BindAddress] = options.delete(:Host) if options[:Host]
        @server = ::WEBrick::HTTPServer.new(options)
        @server.mount "/", Rack::Handler::WEBrick, app
        trap(:INT) { @server.shutdown }
        trap(:TERM) { @server.shutdown }
        yield @server  if block_given?
        @server.start
      end
    end
  end

 if Rack.release  <= "1.2"
  # The Tempfile bug is fixed in the bundled version of Rack
  class RewindableInput
    def make_rewindable
      # Buffer all data into a tempfile. Since this tempfile is private to this
      # RewindableInput object, we chmod it so that nobody else can read or write
      # it. On POSIX filesystems we also unlink the file so that it doesn't
      # even have a file entry on the filesystem anymore, though we can still
      # access it because we have the file handle open.
      @rewindable_io = Tempfile.new('RackRewindableInput')
      @rewindable_io.chmod(0000)
      @rewindable_io.set_encoding(Encoding::BINARY) if @rewindable_io.respond_to?(:set_encoding)
      @rewindable_io.binmode
      if filesystem_has_posix_semantics? && !tempfile_unlink_contains_bug?
        @rewindable_io.unlink
        @unlinked = true
      end
      
      buffer = ""
      while @io.read(1024 * 4, buffer)
        entire_buffer_written_out = false
        while !entire_buffer_written_out
          written = @rewindable_io.write(buffer)
          entire_buffer_written_out = written == Rack::Utils.bytesize(buffer)
          if !entire_buffer_written_out
            buffer.slice!(0 .. written - 1)
          end
        end
      end
      @rewindable_io.rewind
    end

    def tempfile_unlink_contains_bug?
      # The tempfile library as included in Ruby 1.9.1-p152 and later
      # contains a bug: unlinking an open Tempfile object also closes
      # it, which breaks our expected POSIX semantics. This problem
      # has been fixed in Ruby 1.9.2, but the Ruby team chose not to
      # include the bug fix in later versions of the 1.9.1 series.
      ruby_engine = defined?(RUBY_ENGINE) ? RUBY_ENGINE : "ruby"
      ruby_engine == "ruby" && RUBY_VERSION == "1.9.1" && RUBY_PATCHLEVEL >= 152
    end
  end
 end
 
end