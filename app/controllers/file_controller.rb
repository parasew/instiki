# Controller responsible for serving files and pictures.

require 'zip/zip'
require 'instiki_stringsupport'

class FileController < ApplicationController

  layout 'default'
  
  before_filter :check_authorized
  before_filter :check_allow_uploads, :dnsbl_check, :except => [:file, :blahtex_png]

  def file
    @file_name = params['id']
    if params['file']
      return unless is_post and check_allow_uploads
      # form supplied
      new_file = @web.wiki_files.create(params['file'])
      if new_file.valid?
        flash[:info] = "File '#{@file_name}' successfully uploaded"
        redirect_to(params['referring_page'])
      else
        # pass the file with errors back into the form
        @file = new_file
        render
      end
    else
      # no form supplied, this is a request to download the file
      file = @web.files_path.join(@file_name)
      if File.exists?(file)
        send_file(file)
      else
        return unless check_allow_uploads
        @file = WikiFile.new(:file_name => @file_name)
        render
      end
    end
  end
  
  def blahtex_png
    send_file(@web.blahtex_pngs_path.join(params['id']))
  end
    
  def delete
    @file_name = params['id']
    file = WikiFile.find_by_file_name(@file_name)
    unless file
      flash[:error] = "File '#{@file_name}' not found."
      redirect_to_page(@page_name)
    end
    system_password = params['system_password']
    if system_password
      return unless is_post
      # form supplied
      if wiki.authenticate(system_password)
         file.destroy
         flash[:info] = "File '#{@file_name}' deleted."
       else
        flash[:error] = "System Password incorrect."        
      end
      redirect_to_page(@page_name)
    else
    # no system password supplied, display the form
    end
  end

  def cancel_upload
    return_to_last_remembered
  end
  
  def import
    if params['file']
      @problems = []
      import_file_name = "#{@web.address}-import-#{Time.now.strftime('%Y-%m-%d-%H-%M-%S')}.zip"
      import_from_archive(params['file'].path)
      if @problems.empty?
        flash[:info] = 'Import successfully finished'
      else
        flash[:error] = 'Import finished, but some pages were not imported:<li>' + 
            @problems.join('</li><li>') + '</li>'
      end
      return_to_last_remembered
    else
      # to template
    end
  end

  protected
  
  def check_authorized
    if authorized? or @web.published?
      return true
    else
      @hide_navigation  = true
      render(:status => 403, :text => 'This web is private', :layout => true)
      return false
    end    
  end

  def check_allow_uploads
    render(:status => 404, :text => "Web #{params['web'].inspect} not found", :layout => 'error') and return false unless @web
    if @web.allow_uploads? and authorized?
      return true
    else
      @hide_navigation  = true
      render(:status => 403, :text => 'File uploads are blocked by the webmaster', :layout => true)
      return false
    end
  end
  
  private 
  
  def import_from_archive(archive)
    logger.info "Importing pages from #{archive}"
    zip = Zip::ZipInputStream.open(archive)
    while (entry = zip.get_next_entry) do
      ext_length = File.extname(entry.name).length
      page_name = entry.name[0..-(ext_length + 1)].purify
      page_content = entry.get_input_stream.read.purify
      logger.info "Processing page '#{page_name}'"
      begin
        existing_page = @wiki.read_page(@web.address, page_name)
        if existing_page
          if existing_page.content == page_content
            logger.info "Page '#{page_name}' with the same content already exists. Skipping."
            next
          else
            logger.info "Page '#{page_name}' already exists. Adding a new revision to it."
            wiki.revise_page(@web.address, page_name, page_name, page_content, Time.now, @author, PageRenderer.new)
          end
        else
          wiki.write_page(@web.address, page_name, page_content, Time.now, @author, PageRenderer.new)
        end
      rescue => e
        logger.error(e)
        @problems << "#{page_name} : #{e.message}"
      end
    end
    logger.info "Import from #{archive} finished"
  end

end
