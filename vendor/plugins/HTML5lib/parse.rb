#!/usr/bin/env ruby
# 
# Parse a document to a simpletree tree, with optional profiling

$:.unshift File.dirname(__FILE__),'lib'

def parse(opts, args)

  f = args[-1]
  if f
    begin
      require 'open-uri' if f[0..6] == 'http://'
      f = open(f)
    rescue
    end
  else
    $stderr.write("No filename provided. Use -h for help\n")
    exit(1)
  end

  require 'html5lib/treebuilders'
  treebuilder = HTML5lib::TreeBuilders[opts.treebuilder]

  if opts.output == :xml
    require 'html5lib/liberalxmlparser'
    p = HTML5lib::XHTMLParser.new(:tree=>treebuilder)
  else
    require 'html5lib/html5parser'
    p = HTML5lib::HTMLParser.new(:tree=>treebuilder)
  end

  if opts.profile
    require 'profiler'
    Profiler__::start_profile
    p.send(opts.parsemethod,f)
    Profiler__::stop_profile
    Profiler__::print_profile($stderr)
  elsif opts.time
    require 'time'
    t0 = Time.new
    document = p.send(opts.parsemethod,f)
    t1 = Time.new
    printOutput(p, document, opts)
    t2 = Time.new
    puts "\n\nRun took: %fs (plus %fs to print the output)"%[t1-t0, t2-t1]
  else
    document = p.send(opts.parsemethod,f)
    printOutput(p, document, opts)
  end
end

def printOutput(parser, document, opts)
  puts "Encoding: #{parser.tokenizer.stream.char_encoding}" if opts.encoding

  case opts.output
  when :xml
    print document
  when :html
    require 'html5lib/treewalkers'
    tokens = HTML5lib::TreeWalkers[opts.treebuilder].new(document)
    require 'html5lib/serializer'
    print HTML5lib::HTMLSerializer.serialize(tokens, opts.serializer)
  when :hilite
    print document.hilite
  when :tree
    document = [document] unless document.respond_to?(:each)
    document.each {|fragment| puts parser.tree.testSerializer(fragment)}
  end

  if opts.error
    errList=[]
    for pos, message in parser.errors
        errList << ("Line %i Col %i"%pos + " " + message)
    end
    $stdout.write("\nParse errors:\n" + errList.join("\n")+"\n")
  end
end

require 'ostruct'
options = OpenStruct.new
options.profile = false
options.time = false
options.output = :html
options.treebuilder = 'simpletree'
options.error = false
options.encoding = false
options.parsemethod = :parse
options.serializer = {
  :encoding => 'utf-8',
  :omit_optional_tags => false,
  :inject_meta_charset => false
}

require 'optparse'
opts = OptionParser.new do |opts|
  opts.on("-p", "--[no-]profile", "Profile the run") do |profile|
    options.profile = profile
  end
    
  opts.on("-t", "--[no-]time", "Time the run") do |time|
    options.time = time
  end
    
  opts.on("-b", "--treebuilder NAME") do |treebuilder|
    options.treebuilder = treebuilder
  end

  opts.on("-e", "--error", "Print a list of parse errors") do |error|
    options.error = error
  end

  opts.on("-f", "--fragment", "Parse as a fragment") do |parse|
    options.parsemethod = :parseFragment
  end

  opts.on("--tree", "output as debug tree") do |tree|
    options.output = :tree
  end
  
  opts.on("-x", "--xml", "output as xml") do |xml|
    options.output = :xml
    options.treebuilder = "rexml"
  end
  
  opts.on("--[no-]html", "Output as html") do |html|
    options.output = (html ? :html : nil)
  end
  
  opts.on("--hilite", "Output as formatted highlighted code.") do |hilite|
    options.output = :hilite
  end
  
  opts.on("-c", "--[no-]encoding", "Print character encoding used") do |encoding|
    options.encoding = encoding
  end

  opts.on("--[no-]inject-meta-charset", "inject <meta charset>") do |inject|
    options.serializer[:inject_meta_charset] = inject
  end

  opts.on("--[no-]strip-whitespace", "strip unnecessary whitespace") do |strip|
    options.serializer[:strip_whitespace] = strip
  end

  opts.on("--[no-]sanitize", "escape unsafe tags") do |sanitize|
    options.serializer[:sanitize] = sanitize
  end

  opts.on("--[no-]omit-optional-tags", "Omit optional tags") do |omit|
    options.serializer[:omit_optional_tags] = omit
  end

  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end

opts.parse!(ARGV)
parse options, ARGV
