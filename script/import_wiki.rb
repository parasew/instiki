require 'optparse'

puts 'Instiki import'
puts 

ARGV << '-t' << 'tmp-instiki' << '/rails.zip'

IMPORT_OPTIONS = {
  
}

argv_before_parsing_by_import = ARGV.dup

ARGV.options do |opts|
  script_name = File.basename($0)
  opts.banner = "Usage: ruby #{script_name} [options] [import file]"

  opts.separator ''

  opts.on('-w', '--web-address', 
          'Web address to import '
          ) { IMPORT_OPTIONS[:web] }
  opts.on('-t', '--storage=storage', String,
          'Makes Instiki use the specified directory for storage.',
          'Default: ./storage/[port]') { |IMPORT_OPTIONS[:storage]| }

  opts.separator ''

  opts.on('-h', '--help',
          'Show this help message.') { puts opts; exit }

  opts.parse!
end

raise 'Please specify the import file' if ARGV.empty?
import_file = ARGV.last
raise "Import file not found: #{import_file}" unless File.file?(import_file)
raise "Can not read import file: #{import_file}" unless File.readable?(import_file)

raise 'Please specify the storage path' unless IMPORT_OPTIONS[:storage]

INSTIKI_BATCH_JOB = true
ARGV.clear
argv_before_parsing_by_import.each { |arg| ARGV << arg }

load "#{File.dirname(__FILE__)}/server"

wiki = WikiService.instance

web_address = IMPORT_OPTIONS[:web] 

if web_address.nil?
  if wiki.webs.empty?
    puts "Instiki storage at #{IMPORT_OPTIONS[:storage]} is new (no webs)."
    puts "Creating a new web named 'wiki', without a password"
    web = wiki.create_web('Wiki', 'wiki')
  elsif wiki.webs.values.size == 1
    web = wiki.webs.values.first
    puts "Instiki storage at #{IMPORT_OPTIONS[:storage]} contains one web, '#{web.address}'."
    puts "Pages are imported into this web"
  end
else
  web = wiki.webs[web_address]
  if web.nil?
    raise "Instiki storage at #{IMPORT_OPTIONS[:storage]} has no web named '#{web_address}'"
  end
end

zip = Zip::ZipInputStream.open(import_file)

while (entry = zip.get_next_entry) do
  ext_length = File.extname(entry.name).length
  page_name = entry.name[0..-(ext_length + 1)]
  page_content = entry.get_input_stream.read
  
  puts "Processing page '#{page_name}'"
  
  if wiki.read_page(web_address, page_name)
    wiki.revise_page(web.address, page_name, page_content, Time.now, 'Importer')
  else
    wiki.write_page(web.address, page_name, page_content, Time.now, 'Importer')
  end
end

puts "Import finished"
