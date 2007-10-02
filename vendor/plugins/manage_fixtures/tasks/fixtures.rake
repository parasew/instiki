require File.join(File.dirname(__FILE__), '..', 'lib', 'manage_fixtures.rb')

desc "use rake db:fixtures:export_using_query SQL=\"select * from foo where id='bar'\" FIXTURE_NAME=foo"
namespace :db do  
  namespace :fixtures do
    task :export_using_query => :environment do
      write_yaml_fixtures_to_file(ENV['SQL'], ENV['FIXTURE_NAME'])
    end
  end
end
 
desc 'use rake db:fixtures:export_for_tables TABLES=foos[,bars,lands] Create YAML test fixtures for a specific table(s) from data in an existing database. Defaults to development database. Set RAILS_ENV to override. ' 
namespace :db do  
  namespace :fixtures do
    task :export_for_tables => :environment do 
      sql = "SELECT * FROM %s" 
      tables = ENV['TABLES'] 
      ActiveRecord::Base.establish_connection 
      tables.each do |table_name| 
        write_yaml_fixtures_to_file(sql % table_name, table_name)
      end 
    end
  end
end 
 
 
desc ' Create YAML test fixtures from data in an existing database. Defaults to development database. Set RAILS_ENV to override. ' 
namespace :db do  
  namespace :fixtures do
    task :export_all => :environment do 
      sql = "SELECT * FROM %s" 
      skip_tables = ["schema_info"] 
      ActiveRecord::Base.establish_connection 
      (ActiveRecord::Base.connection.tables - skip_tables).each do |table_name| 
        i = "000" 
        File.open("#{RAILS_ROOT}/test/fixtures/#{table_name}.yml", 'w' ) do |file| 
          write_yaml_fixtures_to_file(sql % table_name, table_name)
        end 
      end 
    end
  end
end 

desc 'use rake db:fixtures:import_for_models MODELS=Foo[,Bar,Land] to import the YAML test fixtures for a specific models from data in an existing database. Defaults to development database. Set RAILS_ENV to override. '
namespace :db do
  namespace :fixtures do
    task :import_for_models => :environment do
      models = ENV['MODELS']
      ActiveRecord::Base.establish_connection
      models.each do |model_name|
        import_model_fixture(model_name)
      end
    end
  end
end


desc 'use rake db:fixtures:import_for_tables TABLES=foos[,bars,lands] to import the YAML test fixtures for a specific tables from data in an existing database. Defaults to development database. Set RAILS_ENV to override. '
namespace :db do
  namespace :fixtures do
    task :import_for_tables => :environment do
      tables = ENV['TABLES']
      ActiveRecord::Base.establish_connection
      tables.each do |table_name|
        import_table_fixture(table_name)
      end
    end
  end
end

desc 'use rake db:fixtures:import_all to import all YAML test fixtures for all of the tables from data in an existing database. Defaults to development database. Set RAILS_ENV to override. '
namespace :db do
  namespace :fixtures do
    task :import_all => :environment do
      ActiveRecord::Base.establish_connection
      Dir.glob(File.join(RAILS_ROOT,'test','fixtures',"*.yml")).each do |f|
        table_name = f.gsub(File.join(RAILS_ROOT,'test','fixtures', ''), '').gsub('.yml', '')
        import_table_fixture(table_name)
      end
    end
  end
end

