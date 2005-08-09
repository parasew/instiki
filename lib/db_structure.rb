require 'erb'

def create_options
  if @db == 'mysql'
    'ENGINE = ' + (mysql_engine rescue @mysql_engine)
  end
end

def db_quote(column)
  case @db
  when 'postgresql'
    return "\"#{column}\""
  when 'sqlite', 'sqlite3'
    return "'#{column}'"
  when 'mysql'
    return "`#{column}`"
  end
end

def db_structure(db)
  db.downcase!
  @db = db
  case db
  when 'postgresql'
    @pk = 'SERIAL PRIMARY KEY'
    @datetime = 'TIMESTAMP'
    @boolean = "BOOLEAN"
  when 'sqlite', 'sqlite3'
    @pk = 'INTEGER PRIMARY KEY'
    @datetime = 'DATETIME'
    @boolean = "INTEGER"
  when 'mysql'
    @pk = 'INTEGER UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY'
    @datetime = 'DATETIME'
    @boolean = "TINYINT"
    @mysql_engine = 'InnoDB'
  else
    raise "Unknown db type #{db}"
  end

  s = ''
  Dir[RAILS_ROOT + '/db/*.erbsql'].each do |filename|
    s += ERB.new(File.read(filename)).result
  end
  s
end
