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

def delete row
  path = row[0]
  sql =<<-SQL
delete from crawler where path = :path
SQL
  db = SQLite3::Database.new(SQLITEFILE)
  db.execute sql,{ :path => path }
  db.close
  puts "delete #{path}"
end

def selectAll
  sql =<<-SQL
select path from crawler
SQL
  db = SQLite3::Database.new(SQLITEFILE)
  result = db.execute sql
  db.close
  return result
end

def exists? row
  return File.exists? row[0]
end

# 能率悪いけどin区に値を入れ込む方法をしらぬ。
def check_and_delete_duplicate
  sql =<<-SQL
select id,path,count(*) from crawler group by path having count(*) > 1
SQL
  db = SQLite3::Database.new(SQLITEFILE)
  results = db.execute sql
  sql2 =<<-SQL
select id,path from crawler where path = :path 
SQL
  sql3 =<<-SQL
delete from crawler where id = :id 
SQL
  results.each do |row|
    rows = db.execute sql2,{ :path => row[1] }
    ids = []
    rows.each do |r|
      ids << r
    end
    ids.shift
    ids.each do |r|
      puts "delete #{r[0]} - #{r[1]}"
      db.execute sql3,{ :id => r[0] }
    end
  end
  db.close
end

#---------------
# main

create_db

filelist = selectAll

filelist.each{|row|
  delete row unless exists? row
}
check_and_delete_duplicate
