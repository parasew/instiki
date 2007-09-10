# adapted from feedvalidator, original copyright license is
#
# Copyright (c) 2002-2006, Sam Ruby, Mark Pilgrim, Joseph Walton, and Phil Ringnalda
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

iana_schemes = [ # http://www.iana.org/assignments/uri-schemes.html
  "ftp", "http", "gopher", "mailto", "news", "nntp", "telnet", "wais",
  "file", "prospero", "z39.50s", "z39.50r", "cid", "mid", "vemmi",
  "service", "imap", "nfs", "acap", "rtsp", "tip", "pop", "data", "dav",
  "opaquelocktoken", "sip", "sips", "tel", "fax", "modem", "ldap",
  "https", "soap.beep", "soap.beeps", "xmlrpc.beep", "xmlrpc.beeps",
  "urn", "go", "h323", "ipp", "tftp", "mupdate", "pres", "im", "mtqp",
  "iris.beep", "dict", "snmp", "crid", "tag", "dns", "info"
]
ALLOWED_SCHEMES = iana_schemes + ['javascript']

RFC2396      = Regexp.new("^([a-zA-Z][0-9a-zA-Z+\\-\\.]*:)?/{0,2}[0-9a-zA-Z;/?:@&=+$\\.\\-_!~*'()%,#]*$", Regexp::MULTILINE)
rfc2396_full = Regexp.new("[a-zA-Z][0-9a-zA-Z+\\-\\.]*:(//)?[0-9a-zA-Z;/?:@&=+$\\.\\-_!~*'()%,#]+$")
URN = Regexp.new("^[Uu][Rr][Nn]:[a-zA-Z0-9][a-zA-Z0-9-]{1,31}:([a-zA-Z0-9()+,\.:=@;$_!*'\-]|%[0-9A-Fa-f]{2})+$")
TAG = Regexp.new("^tag:([a-z0-9\\-\._]+?@)?[a-z0-9\.\-]+?,\d{4}(-\d{2}(-\d{2})?)?:[0-9a-zA-Z;/\?:@&=+$\.\-_!~*'\(\)%,]*(#[0-9a-zA-Z;/\?:@&=+$\.\-_!~*'\(\)%,]*)?$")

def is_valid_uri(value, uri_pattern = RFC2396)
  scheme = value.split(':').first
  scheme.downcase! if scheme
  if scheme == 'tag'
    if !TAG.match(value)
      return false, "invalid-tag-uri"
    end
  elsif scheme == "urn"
    if !URN.match(value)
      return false, "invalid-urn"
    end
  elsif uri_pattern.match(value).to_a.reject{|i| i == ''}.compact.length == 0 || uri_pattern.match(value)[0] != value
    urichars = Regexp.new("^[0-9a-zA-Z;/?:@&=+$\\.\\-_!~*'()%,#]$", Regexp::MULTILINE)
    if value.length > 0
      value.each_byte do |b|
        if b < 128 and !urichars.match([b].pack('c*'))
          return false, "invalid-uri-char"
        end
      end
    else
      begin
        if uri_pattern.match(value.encode('idna'))
          return false, "uri-not-iri"
        end
      rescue
      end
      return false, "invalid-uri"
    end
  elsif ['http','ftp'].include?(scheme)
    if !value.match(%r{^\w+://[^/].*})
      return false, "invalid-http-or-ftp-uri"
    end
  elsif value.index(':') && scheme.match(/^[a-z]+$/) && !ALLOWED_SCHEMES.include?(scheme)
    return false, "invalid-scheme"
  end
  return true, ""
end

def is_valid_iri(value)
  begin
    if value.length > 0
      value = value.encode('idna')
    end
  rescue
  end
  is_valid_uri(value)
end

def is_valid_fully_qualified_uri(value)
  is_valid_uri(value, rfc2396_full)
end
