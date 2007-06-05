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
    p.parse(f)
    Profiler__::stop_profile
    Profiler__::print_profile($stderr)
  elsif opts.time
    require 'time'
    t0 = Time.new
    document = p.parse(f)
    t1 = Time.new
    printOutput(p, document, opts)
    t2 = Time.new
    puts "\n\nRun took: %fs (plus %fs to print the output)"%[t1-t0, t2-t1]
  else
    document = p.parse(f)
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
    print HTML5lib::HTMLSerializer.serialize(tokens, :encoding=>'utf-8')
  when :hilite
    print document.hilite
  when :tree
    print parser.tree.testSerializer(document)
  end

  if opts.error
    errList=[]
    for pos, message in parser.errors
        errList << ("Line %i Col %i"%pos + " " + message)
    end
    $stderr.write("\nParse errors:\n" + errList.join("\n")+"\n")
  end
end

require 'ostruct'
options = OpenStruct.new
options.profile = false
options.time = false
options.output = :tree
options.treebuilder = 'simpletree'
options.error = false
options.encoding = false

require 'optparse'
opts = OptionParser.new do |opts|
  opts.on("-p", "--[no-]profile", "Profile the run") do |profile|
    options.profile = profile
  end
    
  opts.on("-t", "--[no-]time", "Time the run") do |time|
    options.time = time
  end
    
  opts.on("--[no-]tree", "Do not print output tree") do |tree|
    if tree
      options.output = :tree
    else
      options.output = nil
    end
  end
  
  opts.on("-b", "--treebuilder NAME") do |treebuilder|
    options.treebuilder = treebuilder
  end

  opts.on("-e", "--error", "Print a list of parse errors") do |error|
    options.error = error
  end

  opts.on("-x", "--xml", "output as xml") do |xml|
    options.output = :xml
    options.treebuilder = "rexml"
  end
  
  opts.on("--html", "Output as html") do |html|
    options.output = :html
  end
  
  opts.on("--hilite", "Output as formatted highlighted code.") do |hilite|
    options.output = :hilite
  end
  
  opts.on("-c", "--[no-]encoding", "Print character encoding used") do |encoding|
    options.encoding = encoding
  end

  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end

opts.parse!(ARGV)
parse options, ARGV
