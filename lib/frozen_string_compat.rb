# String#as_utf8 / #as_bytes from the itextomml gem (lib/itex_stringsupport.rb)
# are defined as in-place `force_encoding(...)`. They raise FrozenError on
# strings that come back from sqlite3 2.x adapter, which returns frozen
# rows. Re-open the class and return a duped copy when the receiver is
# frozen, so existing call sites (`row['name'].as_utf8`,
# `read_attribute(:content).as_utf8`) keep working without rewriting them.
#
# The itextomml gem is loaded eagerly during boot (via maruku's engine
# init), so its definitions are in place by the time we override here.

require "itex_stringsupport"

class String
  def as_utf8
    if frozen?
      dup.force_encoding("UTF-8")
    else
      force_encoding("UTF-8")
    end
  end

  def as_bytes
    if frozen?
      dup.force_encoding("ASCII-8BIT")
    else
      force_encoding("ASCII-8BIT")
    end
  end
end
