#! /usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'sqlite3'

SQLITEFILE = "/home/seijiro/crawler/crawler.db"

# @see http://takuya-1st.hatenablog.jp/entry/2015/07/15/002701
def create_gif path
  begin
    giffilename = mkgifpath path
    command_0 = "rm -f /var/smb/sdc1/video/gif/tmp/* && rm -f /var/smb/sdc1/video/gif/tmp/.*"
    command_1 = "ffmpeg -t 120 -i '#{path}' -an -r 1 -s 160x90 -pix_fmt rgb24 /var/smb/sdc1/video/gif/tmp/%010d.png"
    ##command_1 = "ffmpeg -t 120 -i '#{path}' -an -r 1 -pix_fmt rgb24 /var/smb/sdc1/video/gif/tmp/%010d.png"
    command_2 = "find /var/smb/sdc1/video/gif/tmp/ -type f -name '*.png' | xargs -P0 -I@ mogrify -resize 160x90 @ "
    command_3 = "convert /var/smb/sdc1/video/gif/tmp/*.png '#{giffilename}' "
    command_4 = "rm -f /var/smb/sdc1/video/gif/tmp/* && rm -f /var/smb/sdc1/video/gif/tmp/.*"
    system command_0
    system command_1
    ##system command_2
    system command_3
    system command_4
    #command_ffmpeg = "ffmpeg -ss 9 -i '#{path}' -t 30 -an -r 100 -s 160x90 -pix_fmt rgb24 -f gif '#{giffilename}'  "
    #system command_ffmpeg 
  rescue => ex
    p ex
  end
end

def gifexists? path
  return File.exists? (mkgifpath path)
end

def mkgifpath path
  filename =  File.basename(path).gsub(/flv$/i,"gif").gsub(/mp4$/i,"gif")
  filename =  filename.gsub(/mkv$/i,"gif").gsub(/avi$/i,"gif")
  filename =  filename.gsub(/rmvb$/i,"gif")
  filename =  filename.gsub(/MOV$/i,"gif")
  filename =  filename.gsub(/m4v$/i,"gif")
  # gifpath = "/var/smb/sdc1/video/tmp/" + filename
  # command = "rm -f '#{gifpath}' "
  # puts command
  # system command
  return "/var/smb/sdc1/video/gif/" + filename
end

def get_list
  sql =<<-SQL
select path from crawler
SQL
  db = SQLite3::Database.new(SQLITEFILE)
  result = db.execute sql
  db.close
  result.map{|e| e[0] }
end

#---------------
# main

get_list.sort.each{|path|
  create_gif path unless gifexists? path
}

