CREATE TABLE pages (
  id INTEGER PRIMARY KEY,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  web_id INTEGER NOT NULL,
  locked_by VARCHAR(60),
  name VARCHAR(60),
  locked_at DATETIME
);
CREATE TABLE revisions (
    id INTEGER PRIMARY KEY,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    page_id INTEGER NOT NULL,
    content TEXT NOT NULL,
    author VARCHAR(60),
    ip VARCHAR(60),
    number INTEGER
);
CREATE TABLE system (
    id INTEGER PRIMARY KEY,
    'password' VARCHAR(60)
);
CREATE TABLE webs (
  id INTEGER PRIMARY KEY,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  name VARCHAR(60) NOT NULL,
  address VARCHAR(60) NOT NULL,
  'password' VARCHAR(60),
  additional_style VARCHAR(255),
  allow_uploads INTEGER DEFAULT '1',
  published INTEGER DEFAULT '0',
  count_pages INTEGER DEFAULT '0',
  markup VARCHAR(50) DEFAULT 'textile',
  color VARCHAR(6) DEFAULT '008B26',
  max_upload_size INTEGER DEFAULT 100,
  safe_mode INTEGER DEFAULT '0',
  brackets_only INTEGER DEFAULT '0'
);
