# This plugin checks if the client is listed in DNSBLs (DNS Blackhole Lists).
# These are lists of IP addresses misbehaving. There are many DNSBLs, some are more
# aggressive than others. More information at http://en.wikipedia.org/wiki/DNSBL
#
# This plugin will perform one DNS request per client per blocklist.
# This plugin will deny service to clients those blocklists have listed.
# Whether any of this is acceptable is up to you.
#
# mailto:joost@spacebabies.nl
# License: MIT License, like Rails.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# Version 1.3
# http://www.spacebabies.nl/dnsbl_check
require 'resolv'

module DNSBL_Check
  $dnsbl_passed ||= []
  DNSBLS = %w{list.dsbl.org bl.spamcop.net sbl-xbl.spamhaus.org}

  private
  # Filter to check if the client is listed. This will be run before all requests.
  def dnsbl_check
    return true if respond_to?(:logged_in?) && logged_in?
    return true if $dnsbl_passed.include? request.remote_addr

    passed = true
    threads = []
    request.remote_addr =~ /(\d+).(\d+).(\d+).(\d+)/

    # Check the remote address against each dnsbl in a separate thread
    DNSBLS.each do |dnsbl|
      threads << Thread.new("#$4.#$3.#$2.#$1.#{dnsbl}") do |host|
        logger.warn("Checking DNSBL #{host}")
        addr = Resolv.getaddress("#{host}") rescue ''
        if addr[0,7]=="127.0.0"
          logger.info("#{request.remote_addr} found using DNSBL #{host}")
          passed = false
        end
      end
    end
    threads.each {|thread| thread.join(2)}    # join threads, but use timeout to kill blocked ones

    # Add client ip to global passed cache if no dnsbls objected. else deny service.
    if passed
#      $dnsbl_passed = $dnsbl_passed[0,99].unshift request.remote_addr
      $dnsbl_passed.push request.remote_addr
      logger.warn("#{request.remote_addr} added to DNSBL passed cache")
    else
      render :text => 'Access denied', :status => 403
      return false
    end
  end
end
