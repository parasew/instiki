require 'fileutils'
require 'application'
require 'instiki_errors'

class FileController < ApplicationController

  layout 'default'

  def file
    sanitize_file_name
    if @params['file']
      # form supplied
      upload_file
      flash[:info] = "File '#{@file_name}' successfully uploaded"
      return_to_last_remembered
    elsif have_file?
      send_file(file_path)
    else
      logger.debug("File not found: #{file_path}")
      # go to the template, which is a file upload form
    end
  end

  def cancel_upload
    return_to_last_remembered
  end
  
  private

  def have_file?
    File.file?(file_path)
  end

  def upload_file
    if @params['file'].kind_of?(Tempfile)
      @params['file'].close
      FileUtils.mv(@params['file'].path, file_path)
    elsif @params['file'].kind_of?(IO)
      File.open(file_path, 'wb') { |f| f.write(@params['file'].read) }
    else
      raise 'File to be uploaded is not an IO object'
    end
  end

  SANE_FILE_NAME = /[-_\.A-Za-z0-9]{1,255}/

  def sanitize_file_name
    raise Instiki::ValidationError.new("Invalid path: no file name") unless @file_name
    unless @file_name =~ SANE_FILE_NAME
      raise ValidationError.new("Invalid file name: '#{@file_name}'.\n" +
            "Only latin characters, digits, dots, underscores and dashes are accepted.")
    end
  end

  def file_area
    raise Instiki::ValidationError.new("Invalid path: no web name") unless @web_name
    file_area = File.expand_path("#{@wiki.storage_path}/#{@web_name}")
    FileUtils.mkdir_p(file_area) unless File.directory?(file_area)
    file_area
  end

  def file_path
    "#{file_area}/#{@file_name}"
  end

end
