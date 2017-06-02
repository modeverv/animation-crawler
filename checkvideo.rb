#! /bin/env ruby

require 'sqlite3'

SQLITEFILE = "/home/seijiro/crawler/crawler.db"

def create_db
  sql =<<-SQL
CREATE TABLE IF NOT EXISTS crawler(
  id integer primary key,
  name text,
  path text,
  created_at TIMESTAMP DEFAULT (DATETIME('now','localtime'))
);
SQL
  db = SQLite3::Database.new(SQLITEFILE)
  db.execute sql
  db.close
end

def insert path
  sql =<<-SQL
insert into crawler(name,path) values(:name,:path)
SQL
  db = SQLite3::Database.new(SQLITEFILE)
  db.execute sql,{ :name => (File.basename path) ,:path => path }
  db.close
  puts "insert #{path} - #{File::mtime(path)} "
end

def exists? path
  sql =<<-SQL
select * from crawler where path like :path
SQL
  db = SQLite3::Database.new(SQLITEFILE)
  result = db.execute sql,{ :path =>  "%" + path + "%" }
  db.close
  return result.size != 0
end

def my_glob filelist, path
  Dir.glob(path).each do |f|
    filelist << f
  end
  filelist
end

#---------------
# main
create_db

filelist = []

pathlist = [
            "/var/smb/sdb1/video/**/*.m4v",
            "/var/smb/sdc1/video/**/*.m4v",
            "/var/smb/sdb1/video/**/*.MOV",
            "/var/smb/sdc1/video/**/*.MOV",
            "/var/smb/sdc1/video/**/*.mp4",
            "/var/smb/sdc1/video/**/*.flv",
            "/var/smb/sdb1/video/**/*.rmvb",
            "/var/smb/sdb1/video/**/*.avi",
            "/var/smb/sdc1/video/**/*.mkv",
            "/var/smb/sdb1/video/**/*.mkv",
            "/var/smb/sdb1/video/**/*.mp4",
            "/var/smb/sdb1/video/**/*.flv",
            "/var/smb/sdb1/video/**/*.avi",
            "/var/smb/sdc1/video/**/*.avi",            
            "/var/smb/sdb1/video/**/*.wmv",
            "/var/smb/sdc1/video/**/*.wmv",            
           ]

pathlist.each do |path|
  my_glob filelist , path
end

filelist.sort_by { |f| File::mtime(f) }.each { |f|
   insert f unless exists? f
}
