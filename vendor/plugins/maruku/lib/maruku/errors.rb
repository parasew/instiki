#   Copyright (C) 2006  Andrea Censi  <andrea (at) rubyforge.org>
#
# This file is part of Maruku.
#
#   Maruku is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   Maruku is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with Maruku; if not, write to the Free Software
#   Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA


module MaRuKu
  class Exception < RuntimeError; end

  module Errors
    FRAME_WIDTH = 75

    # Properly handles a formatting error.
    # All such errors go through this method.
    #
    # The behavior depends on {MaRuKu::Globals `MaRuKu::Globals[:on_error]`}.
    # If this is `:warning`, this prints the error to stderr
    # (or `@error_stream if` it's defined) and tries to continue.
    # If `:on_error` is `:ignore`, this doesn't print anything
    # and tries to continue. If it's `:raise`, this raises a {MaRuKu::Exception}.
    #
    # By default, `:on_error` is set to `:warning`.
    #
    # @overload def maruku_error(s, src = nil, con = nil)
    # @param s [String] The text of the error
    # @param src [#describe, nil] The source of the error
    # @param con [#describe, nil] The context of the error
    # @raise [MaRuKu::Exception] If `:on_error` is set to `:raise`
    def maruku_error(*args)
      policy = get_setting(:on_error)

      case policy
      when :ignore
      when :raise
        raise_error create_frame(describe_error(*args))
      when :warning
        tell_user create_frame(describe_error(*args))
      else
        raise "Unknown on_error policy: #{policy.inspect}"
      end
    end

    def maruku_recover(*args)
      tell_user create_frame(describe_error(*args))
    end
    alias error maruku_error

    def raise_error(s)
      raise MaRuKu::Exception, s, caller
    end

    def tell_user(s)
      (self.attributes[:error_stream] || $stderr) << s
    end

    private

    def create_frame(s)
      "\n" + <<FRAME
 #{"_" * FRAME_WIDTH}
| Maruku tells you:
+#{"-" * FRAME_WIDTH}
#{s.gsub(/^/, '| ').rstrip}
+#{"-" * FRAME_WIDTH}
#{caller[0...5].join("\n").gsub(/^/, '!')}
\\#{"_" * FRAME_WIDTH}
FRAME
    end

    def describe_error(s, src = nil, con = nil)
      s += "\n#{src.describe}\n" if src
      s += "\n#{con.describe}\n" if con
      s
    end
  end
end
