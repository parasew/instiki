require 'application'

class FileController < ApplicationController

  layout 'default', :except => [:rss_feed, :rss_with_headlines, :tex,  :export_tex, :export_html]

  def file
    if have_file?(@params['id'])
      render_text 'Download file' 
    else 
      render_text 'form'
    end
  end
  
  private
  
  def have_file?(file_name)
    sanitize_file_name(file_name)
    @wiki.storage_path
  end

  SANE_FILE_NAME = /[-_A-Za-z0-9]{1,255}/
  def sanitize_file_name(file_name)
    unless file_name =~ SANE_FILE_NAME
      raise "Invalid file name: '#{file_name}'.\n" +
            "Only latin characters, digits, underscores and dashes are accepted."
    end
  end

end

