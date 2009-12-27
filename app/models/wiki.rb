class Wiki 

  cattr_accessor :storage_path, :logger
  self.storage_path = Rails.root.join('storage')

  def authenticate(password)
    password == (system.password || 'instiki')
  end

  def create_web(name, address, password = nil)
    @webs = nil
    Web.create(:name => name, :address => address, :password => password) 
  end

  def delete_web(address)
    web = Web.find_by_address(address)
    unless web.nil?
      web.destroy
      @webs = nil
    end
  end

  def edit_web(old_address, new_address, name, markup, color, additional_style, safe_mode = false, 
      password = nil, published = false, brackets_only = false, count_pages = false, 
      allow_uploads = true, max_upload_size = nil)

    if not (web = Web.find_by_address(old_address))
      raise Instiki::ValidationError.new("Web with address '#{old_address}' does not exist")
    end
    old_files_path = web.files_path
    
    web.update_attributes(:address => new_address, :name => name, :markup => markup, :color => color, 
      :additional_style => additional_style, :safe_mode => safe_mode, :password => password, :published => published,
      :brackets_only => brackets_only, :count_pages => count_pages, :allow_uploads => allow_uploads, :max_upload_size => max_upload_size)
    @webs = nil
    raise Instiki::ValidationError.new("There is already a web with address '#{new_address}'") unless web.errors.on(:address).nil?
    web
    move_files(old_files_path, web.files_path)
  end
  
  def move_files(old_path, new_path)
    return if new_path == old_path
    default_path = Rails.root.join("webs", "files")
    FileUtils.rmdir(new_path) if File.exist?(new_path)
    if [old_path, new_path].include? default_path
      File.rename(old_path, new_path)
      FileUtils.rmdir(old_path.parent) unless old_path == default_path
    else
      File.rename(old_path.parent, new_path.parent)
    end
   end

  def read_page(web_address, page_name)
    ApplicationController.logger.debug "Reading page '#{page_name}' from web '#{web_address}'"
    web = Web.find_by_address(web_address)
    if web.nil?
      ApplicationController.logger.debug "Web '#{web_address}' not found"
      return nil
    else
      page = web.pages.first(:conditions => ['name = ?', page_name])
      ApplicationController.logger.debug "Page '#{page_name}' #{page.nil? ? 'not' : ''} found"
      return page
    end
  end
  
  def remove_orphaned_pages(web_address)
    web = Web.find_by_address(web_address)
    web.remove_pages(web.select.orphaned_pages)
  end
  
  def remove_orphaned_pages_in_category(web_address,category)
    web = Web.find_by_address(web_address)
    pages_in_category = PageSet.new(web, web.select.pages_in_category(category))
    web.remove_pages(pages_in_category.orphaned_pages)
  end

  def revise_page(web_address, page_name, new_name, content, revised_at, author, renderer)
    page = read_page(web_address, page_name)
    page.revise(content, new_name, revised_at, author, renderer)
  end

  def rollback_page(web_address, page_name, revision_number, time, author_id = nil)
    page = read_page(web_address, page_name)
    page.rollback(revision_number, time, author_id)
  end
  
  def setup(password, web_name, web_address)
    system.update_attribute(:password, password)
    create_web(web_name, web_address)
  end

  def system
    @system ||= (System.first() || System.create)
  end

  def setup?
    Web.count > 0
  end

  def webs
    @webs ||= Web.all.inject({}) { |webs, web| webs.merge(web.address => web) }
  end

  def storage_path
    self.class.storage_path
  end
  
  def write_page(web_address, page_name, content, written_on, author, renderer)
    Web.find_by_address(web_address).add_page(page_name, content, written_on, author, renderer)
  end
end
