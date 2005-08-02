require 'erb'

def create_options
  if @db == 'mysql'
    'ENGINE = ' + (mysql_engine rescue @mysql_engine)
  end
end

def db_structure(db)
  db.downcase!
  @db = db
  case db
  when 'postgresql'
    @pk = 'SERIAL PRIMARY KEY'
    @datetime = 'TIMESTAMP'
  when 'sqlite', 'sqlite3'
    @pk = 'INTEGER PRIMARY KEY'
    @datetime = 'DATETIME'
  when 'mysql'
    @pk = 'INTEGER UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY'
    @datetime = 'DATETIME'
    @mysql_engine = 'InnoDB'
  else
    raise "Unknown db type #{db}"
  end

  s = ''
  Dir['db/*.erbsql'].each do |filename|
    s += ERB.new(File.read(filename)).result
  end
  s
end
