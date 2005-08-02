require 'open-uri'
require 'yaml'
require 'madeleine'
require 'madeleine/automatic'
require 'madeleine/zmarshal'

require 'web'
require 'page'
require 'author'
require 'file_yard'
require 'instiki_errors'

module AbstractWikiService

  attr_reader :webs, :system

  def authenticate(password)
    # system['password'] variant is for compatibility with storages from older versions
    password == (@system[:password] || @system['password'] || 'instiki')
  end

  def create_web(name, address, password = nil)
    @webs[address] = Web.new(self, name, address, password) unless @webs[address]
  end

  def delete_web(address)
    @webs[address] = nil
  end

  def file_yard(web)
    raise "Web #{@web.name} does not belong to this wiki service" unless @webs.values.include?(web)
    # TODO cache FileYards
    FileYard.new("#{self.storage_path}/#{web.address}", web.max_upload_size)
  end

  def init_wiki_service
    @webs = {}
    @system = {}
  end
  
  def edit_web(old_address, new_address, name, markup, color, additional_style, safe_mode = false, 
      password = nil, published = false, brackets_only = false, count_pages = false, 
      allow_uploads = true, max_upload_size = nil)

    if not @webs.key? old_address
      raise Instiki::ValidationError.new("Web with address '#{old_address}' does not exist")
    end

    if old_address != new_address
      if @webs.key? new_address
        raise Instiki::ValidationError.new("There is already a web with address '#{new_address}'")
      end
      @webs[new_address] = @webs[old_address]
      @webs.delete(old_address)
      @webs[new_address].address = new_address
    end

    web = @webs[new_address]
    web.refresh_revisions if settings_changed?(web, markup, safe_mode, brackets_only)

    web.name, web.markup, web.color, web.additional_style, web.safe_mode = 
      name, markup, color, additional_style, safe_mode

    web.password, web.published, web.brackets_only, web.count_pages =
      password, published, brackets_only, count_pages, allow_uploads
    web.allow_uploads, web.max_upload_size = allow_uploads, max_upload_size.to_i
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
  end

  def rollback_page(web_address, page_name, revision_number, created_at, author_id = nil)
    page = read_page(web_address, page_name)
    page.rollback(revision_number, created_at, author_id)
  end
  
  def setup(password, web_name, web_address)
    @system[:password] = password
    create_web(web_name, web_address)
  end

  def setup?
    not (@webs.empty?)
  end

  def storage_path
    self.class.storage_path
  end
  
  def write_page(web_address, page_name, content, written_on, author)
    @webs[web_address].add_page(page_name, content, written_on, author)
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
  
  # These methods do not change the state of persistent objects, and 
  # should not be logged by Madeleine
  automatic_read_only :authenticate, :read_page, :setup?, :webs, :storage_path, :file_yard

  @@storage_path = './storage/'

  class << self

    def check_snapshot_thread
      # @madeleine may not be initialised in unit tests, and in such case there is no need to do anything
      @madeleine.check_snapshot_thread unless @madeleine.nil?
    end
  
    def clean_storage
      MadeleineServer.clean_storage(self)
    end

    # One interesting property of Madeleine as persistence mechanism is that it saves 
    # (and restores) the whole ObjectSpace. And in there, storage from older version may contain 
    # who knows what in temporary variables, such as caches of various kinds.
    # The reason why it is nearly impossible to control is that there may be bugs, people may 
    # use modified versions of things, etc etc etc
    # Therefore, upon loading the storage from a file, it is a good idea to clear all such 
    # variables. It would be better yet if Madeleine could be somehow instructed not to save that 
    # data in a snapshot at all. Alas, such a feature is not presently available.
    def clear_all_caches
      return if @system.webs.nil?
      @system.webs.each_value do |web|
        next if web.nil? or web.pages.nil?
        web.pages.each_value do |page|
          next if page.nil? or page.revisions.nil?
          page.revisions.each { |revision| revision.clear_display_cache }
        end
      end
    end

    def instance
      @madeleine ||= MadeleineServer.new(self)
      @system = @madeleine.system
      clear_all_caches
      return @system
    end

    def snapshot
      @madeleine.snapshot
    end
    
    def storage_path=(storage_path)
      @@storage_path = storage_path
    end

    def storage_path
      @@storage_path
    end
  
  end

  def initialize
    init_wiki_service
  end

end

class MadeleineServer

  attr_reader :storage_path

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
    @storage_path = service.storage_path
    @server = Madeleine::Automatic::AutomaticSnapshotMadeleine.new(service.storage_path, 
      Madeleine::ZMarshal.new) {
      service.new
    }
    @snapshoot_thread_running = false
  end

  def command_log_present?
    not Dir[storage_path + '/*.command_log'].empty?
  end

  def snapshot
    @server.take_snapshot
  end
  
  def check_snapshot_thread
    start_snapshot_thread unless @snapshoot_thread_running
  end
  
  def start_snapshot_thread
    @snapshoot_thread_running = true
    Thread.new(@server) {
      hours_since_last_snapshot = 0
      while true
        begin
          hours_since_last_snapshot += 1
          # Take a snapshot if there is a command log, or 24 hours 
          # have passed since the last snapshot
          if command_log_present? or hours_since_last_snapshot >= 24 
            ActionController::Base.logger.info "[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}] " +
              'Taking a Madeleine snapshot'
            snapshot
            hours_since_last_snapshot = 0
          end
          sleep(1.hour)
        rescue => e
          ActionController::Base.logger.error(e)
          # wait for a minute (not to spoof the log with the same error)
          # and go back into the loop, to keep trying
          sleep(1.minute)
          ActionController::Base.logger.info("Retrying to save a snapshot")
        end
      end
    }
  end

  def system
    @server.system
  end
  
end
