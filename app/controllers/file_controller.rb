require 'fileutils'
require 'application'
require 'instiki_errors'

class FileController < ApplicationController

  layout 'default'

  def file
    raise Instiki::ValidationError.new("Invalid path: no file name") unless @file_name
    raise Instiki::ValidationError.new("Invalid path: no web name") unless @web_name
    raise Instiki::ValidationError.new("Invalid path: unknown web name") unless @web

    file_yard = @wiki.file_yard(@web)
    if @params['file']
      # form supplied
      file_yard.upload(@file_name, @params['file'])
      flash[:info] = "File '#{@file_name}' successfully uploaded"
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
  
end
