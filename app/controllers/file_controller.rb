require 'fileutils'
require 'application'
require 'instiki_errors'

# Controller that is responsible for serving files and pictures.
# Disabled in version 0.10

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
      @web.refresh_pages_with_references(@file_name)
      flash[:info] = "Image '#{@file_name}' successfully uploaded"
      return_to_last_remembered
    elsif file_yard.has_file?(@file_name)
      send_file(file_yard.file_path(@file_name))
    else
      logger.debug("Image not found: #{file_yard.files_path}/#{@file_name}")
      render_action 'file'
    end
  end

  def import
    return if file_uploads_disabled?

    check_authorization
    if @params['file']
      @problems = []
      import_file_name = "#{@web.address}-import-#{Time.now.strftime('%Y-%m-%d-%H-%M-%S')}.zip"
      file_yard.upload_file(import_file_name, @params['file'])
      import_from_archive(file_yard.file_path(import_file_name))
      if @problems.empty?
        flash[:info] = 'Import successfully finished'
      else
        flash[:error] = "Import finished, but some pages were not imported:<li>" + 
            @problems.join('</li><li>') + '</li>'
      end
      return_to_last_remembered
    else
      # to template
    end
  end

  protected

  def check_allow_uploads

    # TODO enable file uploads again after 0.10 release
    unless RAILS_ENV == 'test'
      render_text 'File uploads are not ready for general use in Instiki 0.10', '403 Forbidden'
      return false
    end

    unless @web.allow_uploads?
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

  def import_from_archive(archive)
    logger.info "Importing pages from #{archive}"
    zip = Zip::ZipInputStream.open(archive)
    while (entry = zip.get_next_entry) do
      ext_length = File.extname(entry.name).length
      page_name = entry.name[0..-(ext_length + 1)]
      page_content = entry.get_input_stream.read
      logger.info "Processing page '#{page_name}'"
      begin
        existing_page = @wiki.read_page(@web.address, page_name)
        if existing_page
          if existing_page.content == page_content
            logger.info "Page '#{page_name}' with the same content already exists. Skipping."
            next
          else
            logger.info "Page '#{page_name}' already exists. Adding a new revision to it."
            wiki.revise_page(@web.address, page_name, page_content, Time.now, @author)
          end
        else
          wiki.write_page(@web.address, page_name, page_content, Time.now, @author)
        end
      rescue => e
        logger.error(e)
        @problems << "#{page_name} : #{e.message}"
      end
    end
    logger.info "Import from #{archive} finished"
  end

end
