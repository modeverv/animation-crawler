require 'pp'
require 'sqlite3'

def create
  db = SQLite3::Database.new("crawler.db")
  return db
end

def create_table db
  sql = <<-SQL
CREATE TABLE IF NOT EXISTS crawler(
  id integer primary key,
  name text,
  path text,
  created_at TIMESTAMP DEFAULT (DATETIME('now','localtime'))
);
SQL
  db.execute sql
end

def test_insert db
  sql = <<-SQL
insert into crawler(name,path) values('#{Time.now}','/path/to/amime');
SQL
  db.execute sql
end

def test_select db
  sql = <<-SQL
select * from crawler
SQL
  ar = db.execute sql
  ar.each {|row|
    pp row
  }
end

def truncate_table db
  sql = <<-SQL
truncate table crawler
SQL
end
def delete_table db,id
  sql = <<-SQL
delete from crawler where id = :id
SQL
  db.execute(sql,:id => id)
end

# main
db = create
create_table db
10.times {|i|
  #  test_insert db
}
delete_table db , 30
test_select db
# truncate_table db

db.close
