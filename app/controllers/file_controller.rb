require 'fileutils'
require 'application'
require 'instiki_errors'

class FileController < ApplicationController

  layout 'default', :except => [:rss_feed, :rss_with_headlines, :tex,  :export_tex, :export_html]

  def file
    if have_file?
      send_file(file_path)
    else
      render_text 'form'
    end
  end
  
  private
  
  def have_file?
    sanitize_file_name
    File.file?(file_path)
  end

  SANE_FILE_NAME = /[-_A-Za-z0-9]{1,255}/

  def sanitize_file_name
    raise Instiki::ValidationError.new("Invalid path") unless @file_name
    unless @file_name =~ SANE_FILE_NAME
      raise ValidationError.new("Invalid file name: '#{@file_name}'.\n" +
            "Only latin characters, digits, underscores and dashes are accepted.")
    end
  end

  def file_area
    raise Instiki::ValidationError.new("Invalid path") unless @web_name
    file_area = File.expand_path("#{@wiki.storage_path}/#{@web_name}")
    FileUtils.mkdir_p(file_area) unless File.directory?(file_area)
    file_area
  end

  def file_path
    "#{file_area}/#{@file_name}"
  end

end
