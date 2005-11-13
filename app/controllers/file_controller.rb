# Controller responsible for serving files and pictures.

class FileController < ApplicationController

  layout 'default'
  
  before_filter :check_allow_uploads

  def file
    if @params['file']
      # form supplied
      new_file = upload_file(@file_name, @params['file'])
      if new_file.valid?
        flash[:info] = "File '#{@file_name}' successfully uploaded"
        return_to_last_remembered
      else
        # FIXME handle validation errors more gracefully
        flash[:errors] = new_file.errors.to_s
      end
    else 
      # no form supplied, this is a request to download the file
      file = WikiFile.find_by_file_name(@file_name)
      if file 
        send_data(file.content, :filename => @file_name, :type => content_type_header(@file_name))
      end
    end
    # if it's neither a supplied form for upload, nor a request for a known file, 
    # display the file/file.rhtml template (which happens to be an upload form)
  end

  def cancel_upload
    return_to_last_remembered
  end
  
  def import
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
    if @web.allow_uploads?
      return true
    else
      render :status => 403, :text => 'File uploads are blocked by the webmaster' 
      return false
    end
  end

  private 
  
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
