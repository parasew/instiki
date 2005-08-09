require 'fileutils'
require 'instiki_errors'

class FileYard
  cattr_accessor :restrict_upload_access
  restrict_upload_access = true
  attr_reader :files_path

  def initialize(files_path, max_upload_size)
    @files_path, @max_upload_size = files_path, max_upload_size
    FileUtils.mkdir_p(@files_path) unless File.exist?(@files_path)
    @files = Dir["#{@files_path}/*"].collect{|path| File.basename(path) if File.file?(path) }.compact
  end

  def upload_file(name, io)
    sanitize_file_name(name)
    if io.kind_of?(Tempfile)
      io.close
      check_upload_size(io.size)
      File.chmod(600, file_path(name)) if File.exists? file_path(name)
      FileUtils.mv(io.path, file_path(name))
    else
      content = io.read
      check_upload_size(content.length)
      File.open(file_path(name), 'wb') { |f| f.write(content) }
    end
    # just in case, restrict read access and prohibit write access to the uploaded file
    FileUtils.chmod(0440, file_path(name)) if restrict_upload_access
  end

  def files
    Dir["#{files_path}/*"].collect{|path| File.basename(path) if File.file?(path)}.compact
  end

  def has_file?(name)
    files.include?(name)
  end

  def file_path(name)
    "#{files_path}/#{name}"
  end

  SANE_FILE_NAME = /[a-zA-Z0-9\-_\. ]{1,255}/

  def sanitize_file_name(name)
    unless name =~ SANE_FILE_NAME or name == '.' or name == '..'
      raise Instiki::ValidationError.new("Invalid file name: '#{name}'.\n" +
            "Only latin characters, digits, dots, underscores, dashes and spaces are accepted.")
    end
  end
  
  def check_upload_size(actual_upload_size)
    if actual_upload_size > @max_upload_size.kilobytes
      raise Instiki::ValidationError.new("Uploaded file size (#{actual_upload_size / 1024} " + 
              "kbytes) exceeds the maximum (#{@max_upload_size} kbytes) set for this wiki")
    end
  end

end
