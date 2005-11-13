class WikiFile < ActiveRecord::Base
  belongs_to :web
  
  before_save :write_content_to_file
  before_destroy :delete_content_file        
  
  validates_presence_of %w( web file_name description )
  validates_length_of :file_name, :within=>1..50
  validates_length_of :description, :within=>1..255

  def self.find_by_file_name(file_name)
    find(:first, :conditions => ['file_name = ?', file_name])
  end

  SANE_FILE_NAME = /^[a-zA-Z0-9\-_\. ]*$/
  def validate
    if file_name 
      if file_name !~ SANE_FILE_NAME
        errors.add("file_name", "is invalid. Only latin characters, digits, dots, underscores, " +
           "dashes and spaces are accepted")
      elsif file_name == '.' or file_name == '..'
        errors.add("file_name", "cannot be '.' or '..'")
      end
    end
    
    if @web and @content
      if (@content.size > @web.max_upload_size.kilobytes)
        errors.add("content", "size (#{(@content.size / 1024.0).round} kilobytes) exceeds " +
            "the maximum (#{web.max_upload_size} kilobytes) set for this wiki")
      end
    end
    
    errors.add("content", "is empty") if @content.nil? or @content.empty?
  end
  
  def content=(content)
    @content = content
  end
  
  def content
    @content ||= ( File.open(content_path, 'rb') { |f| f.read } )
  end
  
  def content_path
    web.files_path + '/' + file_name
  end
  
  def write_content_to_file
    File.open(self.content_path, 'wb') { |f| f.write(@content) }
  end
  
  def delete_content_file
    require 'fileutils'
    FileUtils.rm_f(content_path) if File.exists?(content_path)
  end
  
end
