require 'sqlite3'

task :upgrade_instiki do
  db = SQLite3::Database.new( "db/production.db.sqlite3" )
  db.execute( "select * from webs" ) do |row|
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
