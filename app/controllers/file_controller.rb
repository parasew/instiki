require 'fileutils'
require 'application'
require 'instiki_errors'

class FileController < ApplicationController

  layout 'default'
  
  before_filter :check_allow_uploads

  def file
    check_path

    if @params['file']
      # form supplied
      file_yard.upload_file(@file_name, @params['file'])
      flash[:info] = "File '#{@file_name}' successfully uploaded"
      @web.refresh_pages_with_references(@file_name)
      return_to_last_remembered
    elsif file_yard.has_file?(@file_name)
      send_file(file_yard.file_path(@file_name))
    else
      logger.debug("File not found: #{file_yard.files_path}/#{@file_name}")
      # go to the template, which is a file upload form
    end
  end

  def cancel_upload
    return_to_last_remembered
  end
  
  def pic
    check_path
    if @params['file']
      # form supplied
      file_yard.upload_file(@file_name, @params['file'])
      flash[:info] = "Image '#{@file_name}' successfully uploaded"
      @web.refresh_pages_with_references(@file_name)
      return_to_last_remembered
    elsif file_yard.has_file?(@file_name)
      send_file(file_yard.file_path(@file_name))
    else
      logger.debug("Image not found: #{file_yard.files_path}/#{@file_name}")
      render_action 'file'
    end
  end


  protected
  
  def check_allow_uploads
    unless @web.allow_uploads
      render_text 'File uploads are blocked by the webmaster', '403 Forbidden'
      return false
    end
  end


  private 
  
  def check_path
    raise Instiki::ValidationError.new("Invalid path: no file name") unless @file_name
    raise Instiki::ValidationError.new("Invalid path: no web name") unless @web_name
    raise Instiki::ValidationError.new("Invalid path: unknown web name") unless @web
  end
  
  def file_yard
    @wiki.file_yard(@web)
  end
  
end
