require 'active_record'

task :upgrade_instiki => :environment do
  ActiveRecord::Base.establish_connection(:production)
  webs = ActiveRecord::Base.connection.execute( "select * from webs" )
  webs.each do |row|
   if File.exists?('public/' + row[4])
      if File.exists?('webs/' + row[4])
        print "Warning! The directory webs/#{row[4]} already exists. Skipping.\n" 
      else
        File.rename('public/' + row[4], 'webs/' + row[4])
        print "Moved: #{row[4]}\n"
      end
    end
  end
end
