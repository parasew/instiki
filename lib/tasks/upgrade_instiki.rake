task :upgrade_instiki => :environment do
  RAILS_ENV = 'production' unless ENV['RAILS_ENV']
  puts "Upgrading Instiki in #{RAILS_ENV} environment."

  Web.all.each do |web|
    public_path = Rails.root.join("public", web.address)
    if public_path.exist?
      webs_path = Rails.root.join("webs", web.address)
      if webs_path.exist?
        puts "Warning! The directory #{webs_path} already exists. Skipping."
      else
        public_path.rename(webs_path)
        puts "Moved #{public_path} to #{webs_path}"
      end
    end
  end
end
