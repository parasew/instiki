require 'open-uri'
require 'yaml'
require 'madeleine'
require 'madeleine/automatic'
require 'madeleine/zmarshal'

require 'web'
require 'page'
require 'author'

module AbstractWikiService

  attr_reader :webs, :system

  def authenticate(password)
    password == (@system[:password] || 'instiki')
  end

  def create_web(name, address, password = nil)
    @webs[address] = Web.new(name, address, password) unless @webs[address]
  end

  def init_wiki_service
    @webs = {}
    @system = {}
  end
  
  def read_page(web_address, page_name)
    ApplicationController.logger.debug "Reading page '#{page_name}' from web '#{web_address}'"
    web = @webs[web_address]
    if web.nil?
      ApplicationController.logger.debug "Web '#{web_address}' not found"
      return nil
    else
      page = web.pages[page_name]
      ApplicationController.logger.debug "Page '#{page_name}' #{page.nil? ? 'not' : ''} found"
      return page
    end
  end

  def remove_orphaned_pages(web_address)
    @webs[web_address].remove_pages(@webs[web_address].select.orphaned_pages)
  end
  
  def revise_page(web_address, page_name, content, revised_on, author)
    page = read_page(web_address, page_name)
    page.revise(content, revised_on, author)
    page
  end

  def rollback_page(web_address, page_name, revision_number, created_at, author_id = nil)
    page = read_page(web_address, page_name)
    page.rollback(revision_number, created_at, author_id)
    page
  end
  
  def setup(password, web_name, web_address)
    @system[:password] = password
    create_web(web_name, web_address)
  end

  def setup?
    not (@webs.empty?)
  end

  def update_web(old_address, new_address, name, markup, color, additional_style, safe_mode = false, 
      password = nil, published = false, brackets_only = false, count_pages = false)
    if old_address != new_address
      @webs[new_address] = @webs[old_address]
      @webs.delete(old_address)
      @webs[new_address].address = new_address
    end
    
    web = @webs[new_address]
    web.refresh_revisions if settings_changed?(web, markup, safe_mode, brackets_only)
    
    web.name, web.markup, web.color, web.additional_style, web.safe_mode = 
      name, markup, color, additional_style, safe_mode
      
    web.password, web.published, web.brackets_only, web.count_pages =
      password, published, brackets_only, count_pages
  end

  def write_page(web_address, page_name, content, written_on, author)
    page = Page.new(@webs[web_address], page_name, content, written_on, author)
    @webs[web_address].add_page(page)
    page
  end
  
  private
    def settings_changed?(web, markup, safe_mode, brackets_only)
      web.markup != markup || 
      web.safe_mode != safe_mode || 
      web.brackets_only != brackets_only
    end
end

class WikiService

  include AbstractWikiService
  include Madeleine::Automatic::Interceptor

  @@storage_path = './storage/'

  class << self
    def storage_path
      @@storage_path
    end
  
    def storage_path=(storage_path)
      @@storage_path = storage_path
    end

    def clean_storage
      MadeleineServer.clean_storage(self)
    end

    def instance
      @system ||= MadeleineServer.new(self).system
    end
  end

  def initialize
    init_wiki_service
  end

end

class MadeleineServer
  SNAPSHOT_INTERVAL   = 60 * 60 * 24 # Each day
  AUTOMATIC_SNAPSHOTS = true

  # Clears all the command_log and snapshot files located in the storage directory, so the
  # database is essentially dropped and recreated as blank
  def self.clean_storage(service)
    begin 
      Dir.foreach(service.storage_path) do |file|
        if file =~ /(command_log|snapshot)$/
          File.delete(File.join(service.storage_path, file))
        end
      end
    rescue
      Dir.mkdir(service.storage_path)
    end
  end

  def initialize(service)
    @server = Madeleine::Automatic::AutomaticSnapshotMadeleine.new(service.storage_path, 
      Madeleine::ZMarshal.new) {
      service.new
    }
    start_snapshot_thread if AUTOMATIC_SNAPSHOTS
  end

  def system
    @server.system
  end

  def start_snapshot_thread
    Thread.new(@server) {
      while true
        sleep(SNAPSHOT_INTERVAL)
        @server.take_snapshot
      end
    }
  end
  
end
