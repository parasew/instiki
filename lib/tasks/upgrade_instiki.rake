require 'rake'

desc "This task will perform necessary upgrades to your Instiki installation"
task :upgrade_instiki => :environment do
  ENV['RAILS_ENV'] ||= 'production'
  puts "Upgrading Instiki in #{ENV['RAILS_ENV']} environment."

  InstikiUpgrade.migrate_db
  InstikiUpgrade.move_uploaded_files
end

class InstikiUpgrade

  def self.migrate_db
    ActiveRecord::Base.establish_connection ENV['RAILS_ENV']
    Rake::Task["db:migrate"].invoke
  end

  def self.move_uploaded_files
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

end