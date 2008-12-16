This plugin checks if a user of your web application is listed in DNSBLs
(DNS Blackhole Lists). These are lists of misbehaving IP addresses.
There are many DNSBLs, some are more aggressive than others.
More information at http://en.wikipedia.org/wiki/DNSBL

This filter will result in one DNS request for every blocklist that you have
configured. This might be problematic for sites under heavy load, although this
plugin has been used on high-traffic sites without any problem. One DNS
request takes a few miliseconds to complete, after all.


INSTALLATION

1. execute "script/plugin install http://www.spacebabies.nl/svn/dnsbl_check"
2. add "before_filter :dnsbl_check" to controllers that need checking
3. restart your application.


VERSION HISTORY

0.1	18 June 2006		Initial release
0.2	10 June 2006		Renamed to dnsbl_check, bugfix
0.3	20 June 2006		Removed sorbs from distribution, was not supposed to be included (too aggressive)
0.4	18 July 2006		Explicit return false added, moved to a per-controller basis (not global anymore)
1.0	16 August 2006		Renamed 0.4 to 1.0. I have been using the plugin very succesfully for months now.
1.1	17 October 2006		Multithreaded version
1.2	23 October 2006		Using the native Ruby resolver library for better multithreaded support
1.2.1	25 October 2006		Accepts a wider range of dns responses
1.2.2	11 December 2006	dnsbls are seemingly under attack, added code to cope with failing service
1.3	30 November 2007	Chique 403 template, moved to Subversion based installation


MORE INFORMATION

http://spacebabies.nl/dnsbl_check/
joost@spacebabies.nl
