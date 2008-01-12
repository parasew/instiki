# FUNDAMENTAL FLAWS:
# The order of $: must be preserved.  Therefore, there are two sort
# criteria: Versioned files are sorted high; after that, the sort order
# is the order of $:.
# We must preserve the load path; if rexml-2.4 is required in one place,
# all rexml/* packages should be loaded from there.
############################################################################
#                                                                          #
#  This is based on Phil Tomson's                                          #
#  ("ptkwt!shell1#aracnet#com".tr("!#","@."))                              #
#  code.  The changes I made are:                                          #
#  1) The Version class is now a member of the Kernel module, to avoid     #
#     name space conflicts.                                                #
#  2) Version::to_s() returns the original string, not a comma-separated   #
#     string.                                                              #
#  3) The versioning is package based, not file based.  In fact, with      #
#     this, you can't version individual files.  AFAIC, this is better,    #
#     since versioning on individual files is much more tedious than       #
#     package-based versioning, and it is arguably less useful and less    #
#     commonly desired.                                                    #
#  4) Versions can have arbitrary length.  EG: 2.7 < 2.7.1, and "2"        #
#     matches any version that starts with "2", such as "2.5.2.6.7"        #
#                                                                          #
#  The rules are these:                                                    #
#  1) All of the locations in $: will be searched                          #
#  2) The highest version of the package found that satisfies the          #
#     requirements will be used.                                           #
#  3) If there is no versioned package, or no version matches, we default  #
#     to the normal Ruby require mechanism.  This maintains backward       #
#     compatible behavior.                                                 #
#  4) The packages must be installed as foo-x.y.z.  The cardinality of     #
#     the version is not significant, and packages that do not match this  #
#     naming pattern match by default.                                     #
#                                                                          #
#  Rule (1) and (2) mean that the highest matching version anywhere in     #
#  the search path will be used.  Rule (3) and (4) mean that even if       #
#  packages are not installed with this naming convention, programs that   #
#  use require_version will still work.                                    #
#                                                                          #
#  Usage:                                                                  #
#  To use this, require this module.  Then use require_with_ver, instead   #
#  of require in your files.                                               # 
#                                                                          #
#  Examples:                                                               #
#    require_version('rexml/document'){|v| v > '2.0' and v < '2.5'}        #
#    require_version('rexml/document'){|v| v > '2.0'}                      #
#    require_version('rexml/document')                                     #
#    require_version('rexml/document'){|v| v > '2.0'}                      #
#    require_version('rexml/document'){|v| v >= '1.0' and v < '2.0'}       #
#    require_version('rexml/document'){|v| v >= '1.0' and v < '2.0' and    #
#                                          v != '1.7'}                     #
#    require_version('rexml/document'){|v| (v >= '1.0' and                 #
#                                           v < '2.0'  and                 #
#                                           v != '1.7') or                 #
#                                          v == '3.0.1'}                   #
#    require_version('rexml/document'){|v| v.to_s =~ /^2.[02468]/}         #
#                                                                          #
############################################################################

module Kernel
	#########################################################
	# Version - takes a string in the form: 'X1.X2.X3...Xn' #
	# (where 'Xn' is a number)                              #
	#########################################################
	class Version
		include Comparable
		def initialize(str)
			@vs = str.split('.').map!{|i| i.to_i}
		end

		def [](i)
			@vs[i]
		end

		def to_s
			@vs.join('.')
		end

		def <=>(other)
			if other.class == String
				other = Version.new(other)
			end
			@vs.each_with_index { |v,i|
        return 1 unless other[i]
				unless v == other[i]
					return v <=> other[i]
				end
			}
			return 0
		end
	end

  alias :old_require :require

	@@__versioned__ = {}
  def require(file,&b)
		path = file.split('/')
		root = path[0]
		rest = path[1..-1].join('/')
		unless @@__versioned__[root]
			package = File.dirname( file )
			files = []
			$:.each {|dir|
				if File.exists? dir
					fileset = Dir.new(dir).entries.delete_if {|f| 
						fpath = File.join( dir, f )
						!(File.directory?(fpath) and f =~ /^#{root}(-\d(\.\d)*)?$/)
					}
					fileset.collect!{ |f| File.join( dir, f ) }
					files += fileset
				end
			}
			if files.size > 0
				@@__versioned__[root] = files.uniq.sort{|x,y| 
					File.basename(x) <=> File.basename(y)
				}
				@@__versioned__[root].reverse!
			else
				@@__versioned__[root] = [root]
			end
		end
		base = @@__versioned__[root][0]
		if b #block_given?
			p @@__versioned__[root]
			base = @@__versioned__[root].delete_if { |f|
				l = File.basename(f)
				l.include?('-') and yield( Version.new( l.split('-')[1] ) ) and 
				Dir.new(f).entries.include?( rest+".rb" ) ? false : true
			}
			p base
			base = base[0]
		end
		#old_require "#{base}/#{rest}"
		puts <<-EOL
		old_require "#{base}/#{rest}"
		EOL
  end
end

#=begin
# For testing
if $0 == __FILE__
	$: << "./"
	puts "\n\nv > '2.0' and v < '2.5'"
	require('rexml/document'){|v| v > '2.0' and v < '2.5'}
	puts "\n\nv > '2.0' and v < '3'"
	require('rexml/document'){|v| v > '2.0' and v < '3'}
=begin
	puts "\n\nv > '2.0'"
	require('rexml/document'){|v| v > '2.0'}
  require('rexml/document')
  puts "\n\nv > '2.0'"
  require('rexml/document'){|v| v > '2.0'}
  puts "\n\nv >= '1.0' and v < '2.0'"
  require('rexml/document'){|v| v >= '1.0' and v < '2.0'}
  puts "\n\nv >= '1.0' and v < '2.0' and v != '1.7'"
  require('rexml/document'){|v| v >= '1.0' and v < '2.0' and v != '1.7'}
  require('rexml/document'){|v| (v >= '1.0' and
                                         v < '2.0'  and
                                         v != '1.7') or
                                        v == '3.0.1'}
  puts "\n\nv.to_s =~ /^2.[02468]/"
  require('rexml/document'){|v| v.to_s =~ /^2.[02468]/}
	require('rexml/parsers/baseparser' )
=end
end
#=end
