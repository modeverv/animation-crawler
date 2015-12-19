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
select * from crawler where name like :name
SQL
  db = SQLite3::Database.new(SQLITEFILE)
  result = db.execute sql,{ :name =>  "%" + (File.basename path) + "%" }
  db.close
  return result.size != 0
end

def glob_flv
  filelist = []
  Dir.glob("/var/smb/sdb1/video/**/*.flv").each {|f|
    filelist << f
  }
  filelist
end

def glob_mp4
  filelist = []
  Dir.glob("/var/smb/sdb1/video/**/*.mp4").each {|f|
    filelist << f
  }
  filelist
end

def glob_mkv
  filelist = []
  Dir.glob("/var/smb/sdb1/video/**/*.mkv").each {|f|
    filelist << f
  }
  filelist
end

def glob_mkv2
  filelist = []
  Dir.glob("/var/smb/sdc1/video/**/*.mkv").each {|f|
    filelist << f
  }
  filelist
end

def glob_avi
  filelist = []
  Dir.glob("/var/smb/sdb1/video/**/*.avi").each {|f|
    filelist << f
  }
  filelist
end

def glob_rmvb
  filelist = []
  Dir.glob("/var/smb/sdb1/video/**/*.rmvb").each {|f|
    filelist << f
  }
  filelist
end

def glob_flv2
  filelist = []
  Dir.glob("/var/smb/sdc1/video/**/*.flv").each {|f|
    filelist << f
  }
  filelist
end

def glob_mp42
  filelist = []
  Dir.glob("/var/smb/sdc1/video/**/*.mp4").each {|f|
    filelist << f
  }
  filelist
end

def glob_mov
  filelist = []
  Dir.glob("/var/smb/sdc1/video/**/*.MOV").each {|f|
    filelist << f
  }
  filelist
end

def glob_mov2
  filelist = []
  Dir.glob("/var/smb/sdb1/video/**/*.MOV").each {|f|
    filelist << f
  }
  filelist
end

def glob_m4v
  filelist = []
  Dir.glob("/var/smb/sdc1/video/**/*.m4v").each {|f|
    filelist << f
  }
  filelist
end

def glob_m4v2
  filelist = []
  Dir.glob("/var/smb/sdb1/video/**/*.m4v").each {|f|
    filelist << f
  }
  filelist
end

#---------------
# main

create_db

filelist = glob_flv2 + glob_mp42 + glob_flv + glob_mp4 + glob_mkv + glob_mkv2 + glob_avi + glob_rmvb + glob_mov + glob_mov2 + glob_m4v + glob_m4v2 

filelist.sort_by{ |f| File::mtime(f) }.each{|f|
  insert f unless exists? f
}
