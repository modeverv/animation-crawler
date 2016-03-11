# -*- coding: utf-8 -*-
require 'pp'
require './uri.rb'
#require 'uri'
# uriモジュールは|を許容するように変更している
require 'eventmachine'
require 'em-http'
require 'nokogiri'
require 'open-uri'
require 'httpclient'
require 'mechanize'
require 'net/http'
require 'logger'
require 'sqlite3'

class Crawler
  DOWNLOADDIR = "/var/smb/sdc1/video"
  CrawlerLOGGER = Logger.new(DOWNLOADDIR + "/0log/download_#{Time.now.strftime("%Y%m%d")}.log")
  M3UPath = DOWNLOADDIR + "/0m3u/#{Time.now.strftime("%Y%m%d")}.m3u"

  START_URL = 'http://youtubeanisoku1.blog106.fc2.com/'
  AGENT  = Mechanize.new

  CONCURRENCY = 256 #32
  WATCH_INTERVAL = 1
  MEGA = (1024 * 1024).to_f

  JOB_ANISOKUTOP     = 'アニ速TOP'
  JOB_KOUSINPAGE     = '更新ページ'
  JOB_KOBETUPAGE     = '個別ページ'
  JOB_NOSUBSEARCH    = "nosub検索ページ"
  JOB_NOSUBVIDEO     = "nosubビデオページ"
  JOB_CONVERT        = "flv2mp4"

  DBFILE = "crawler.db"
  
  # constructor
  # hash[:ffmpeg] convert or not
  # hash[:debug] debug or not
  # hash[:usecurl] download by curl
  def initialize arghash
    @queue = []
    @queue.push({ kind: JOB_ANISOKUTOP, value: START_URL })
    @fetching = 0
    @downloads = {}
    @ffmpeg = arghash[:ffmpeg] || false
    #@debug  = arghash[:debug] || false
    @usecurl= arghash[:usecurl]|| false
    @_gaman = 60
    @gaman  = @_gaman
    @candidate = {}
    @title = {}
    @titles = {}
    @db = SQLite3::Database.new(DBFILE)
    sql = <<-SQL
CREATE TABLE IF NOT EXISTS crawler(
  id integer primary key,
  name text,
  path text,
  created_at TIMESTAMP DEFAULT (DATETIME('now','localtime'))
);
SQL
    @db.execute sql
    @sql = <<-SQL
insert into crawler(name,path) values(:name,:path)
SQL
    @sql_select = <<-SQL
select * from crawler where name = :name 
SQL
  end

  def run
    EM.run do
      EM.add_periodic_timer(WATCH_INTERVAL) do

        diff = CONCURRENCY - @fetching

        diff.times do
          job = @queue.pop
          unless job
            break
          end

          process job
        end

        if @queue.size == 0
          @gaman -= 1
          print "fetching:#{@fetching} gaman:#{@gaman}\t"
          if @gaman == 0
            puts "finish"
            pp @downloads
            EM::stop_event_loop
            @db.close
          end
        else
          # pp @queue
          # pp @queue.size
          @gaman = @_gaman
          # print "fetching:#{@fetching}\t"
          pp @downloads
        end
      end
    end
  end

  def process job
    @fetching += 1
    case job[:kind]
    when JOB_ANISOKUTOP
      anisokutop job[:value]
    when JOB_KOUSINPAGE
      anisokukousin job[:value]
    when JOB_KOBETUPAGE
      anisokukobetu job[:value]
    when JOB_NOSUBSEARCH
      sleep 0.5
      nosubsearch job[:value]
    when JOB_NOSUBVIDEO
      sleep 0.6
      nosubvideo job[:value]
    when JOB_CONVERT
      convert job[:value]
    end
  end

  # anisoku top
  def anisokutop url
    req = EM::HttpRequest.new(url,:connect_timeout => 50).get

    req.errback { @fetching -= 1 }

    req.callback do
      page = Nokogiri::HTML(req.response)
      page.css(".Top_info div ul li a").each {|a|
        if a.attributes['title'] && a.attributes['title'].value =~ /更新状況/
          # puts "更新状況:" + a.attributes['title']
          CrawlerLOGGER.info "更新状況" + a.attributes['title']
          @queue.push({kind: JOB_KOUSINPAGE, value: a.attributes['href'].value })
        end
      }
      @fetching -= 1
    end
  end

  # anisoku kousin
  def anisokukousin url
    puts "anisokukousin : " + url if @debug
    # CrawlerLOGGER.info "anisokukousin : " + url
    req = EM::HttpRequest.new(url,:connect_timeout => 50).get

    req.errback { @fetching -= 1 }

    req.callback do
      page = Nokogiri::HTML(req.response)
      page.css("ul").each{|ul|
        if ul.attributes["type"] && ul.attributes["type"].value == "square"
          ul.css("li a").each{|a|
            a2job a
          }
        end
      }
      page.css("a").each{|a|
        a2job a
      }
      @fetching -= 1
    end
  end
  
  # a to job 
  def a2job a
    href = ""
    href = a.attributes["href"].value unless a.attributes["href"].nil?
    if href =~ /^http\:\/\/youtubeanisoku1\.blog106\.fc2\.com\/blog-entry-.+?\.html$/
      if a.attributes["title"]
        title = a.attributes["title"].value
      end
      
      unless title
        title = a.text
      end
      
      if title =~ /^.+$/
        title = title.gsub('.','').gsub(" ","",).gsub("/","").gsub("#","").gsub("(","").gsub(")","")#.gsub("'","").gsub(/"/,"").gsub(/\<u\>/,"")
        if @title[title]
          #do nothing
          # puts "skip:" + title
        else
          #if title =~ /落第/ || title =~ /学園/ 
          @title[title] = true
          # puts "do:" + title
          CrawlerLOGGER.info "do:" + title 
          @queue.push({kind: JOB_KOBETUPAGE, value: {title: title, href: href } })
          #end
        end
      end
    end
  end

  # anisoku kobetu
  def anisokukobetu value
    puts "anisokukobetu : " + value.to_s if @debug

    req = EM::HttpRequest.new(value[:href],:connect_timeout => 50).get

    req.errback { @fetching -= 1 }

    req.callback do
      page = Nokogiri::HTML(req.response)
      unless page.title.nil?
      t = page.title.gsub(" ★ You Tube アニ速 ★","").strip
      t = t.gsub('.','').gsub(" ","",).gsub("/","").gsub("#","").gsub("(","").gsub(")","")#.gsub("'","").gsub(/"/,"").gsub(/\<u\>/,"")

      if t
        value[:title] = t
      end
          
      page.css("a").each { |a|
        href = ""
        href = a.attributes["href"].value unless a.attributes["href"].nil?
        if href =~ /http:\/\/www.nosub\.tv/
          unless @titles[value[:title]]
            # puts value[:title] + "-" + href
            @titles[value[:title]] = :pedinding
            @queue.push({kind: JOB_NOSUBSEARCH, value: {title: value[:title], href: href } })
          end
        end
      }
      @fetching -= 1
      end
    end  
  end

  def nosubsearch value
    puts "nosubsearch  : " + value.to_s if @debug
    values = []

    req = EM::HttpRequest.new(value[:href],:connect_timeout => 50).get

    req.errback { @fetching -= 1 }

    req.callback do
      page = Nokogiri::HTML(req.response)
      page.css(".title a[rel='bookmark']").each { |a|
        href = ""
        href = a.attributes["href"].value unless a.attributes["href"].nil?
        episode = a.attributes["title"].value.gsub('.','').gsub(" ","").gsub("/","").gsub("　","").gsub("#","").gsub(":","")#.gsub("(","").gsub(")","")#.gsub(/"/,"").gsub(/\<u\>/,"")
        puts value[:title] + "-" + episode + "-" + href
        # unless episode =~ /アニメPV集/ && episode =~ /\[720p\]/
        unless episode =~ /アニメPV集/ || episode =~ /エヴァンゲリオン新劇場版：序/ || episode =~ /WitchHunterROBIN/
          hash = {title: value[:title] ,episode: episode, href: href }
          values << hash
        end
      }
      @queue.push({kind: JOB_NOSUBVIDEO, value: values })
      @fetching -= 1
    end
  end

  def nosubvideo value
    puts "nosubvideo  : " + value.to_s if @debug

    urls = []
    fetched = false

    value.each { |val|

      if val[:title] =~ /少女たちは荒野を目指す/
         puts "#" * 80
         p val
         puts "#" * 80
      end

      path = mkfilepath val[:title],val[:episode]
      if path =~ /\[720p\]/
      #  return
      end
      # puts "before:" + path
      path = path.gsub("<u>","").gsub("'","").gsub(/"/,"")
      # puts "after:" + path
      pathmp4 = path.gsub(/flv$/,"mp4")

      targetpath = ""
      if File.exists?(path)
        targetpath = path
      else
        targetpath = pathmp4
      end
      
      if File.exists?(targetpath) && File.size(targetpath) > 1024 * 1024 * 2
        puts "already exists. #{targetpath} "
        fetched = true
      end

      if @candidate[path]
        puts "candidate. #{path} "
        fetched = true
      end

      @candidate[path] = :pending

      if fetched
        p "fetched" + val.inspect
        @fetching -= 1
        next
      end
      
      @fetching += 1
      if val[:href] == "http://www.nosub.tv/watch/229866.html"
        puts "荒野8 " * 89
      end
      
      req = EM::HttpRequest.new(val[:href],:connect_timeout => 50).get

      req.errback { @fetching -= 1 }

      req.errback {|client|
        p "download error: #{client.inspect}";
      }

      req.callback do
        page = Nokogiri::HTML(req.response)
        videos = []
        page.css("script[type='text/javascript']").each { |script|
          next unless script.children[0] && script.children[0].to_s =~ /MukioPlayerURI/
          p script.children[0].to_s
          lines = script.children[0].to_s.gsub("\n","").split(";")
          # p lines
          lines.each {|l|
            next unless l =~ /addVideo/
            l =~ /type=(.*?)&/
            url = case $1
                  when "fc2"
                    # type=fc2&vid=
                    # 20160225z3SmPURT
                    # &cid=tYCwQMAQAGGFEGCFcAB1EBGAprXDM2MDcqV177FF5","360pFC2","",1);
                    #"type=fc2&vid=20140106PVrVWc2X&cid=msWVIDBFIbAghSVggCCFVpb0pjZFpWPQyIA19b10","360pFC2","",1);
                    # https://www.nosub.tv/wp-content/plugins/mukiopress//lianyue/?/fc2/20160225z3SmPURT
                    l =~ /vid=(.*?)&/
                    u = "https://www.nosub.tv/wp-content/plugins/mukiopress//lianyue/?/fc2/#{$1}"
                    x = false
                    open(u) {|res|
                        x = res.read
                    }
                    x
                  when "video"
                    l =~ /file=(.*?)&/
                    # puts "video find!! #{$1} #{path} "
                    #http://www.nosub.tv/wp-content/plugins/mukiopress/lianyue/?/url/XBCAVbX1ZVVVUGXB1RTEYVRl9JGF9VUAUDUVUAGRdBHFhEAA4LEgRLWRZWFgkLSlwRA1pFGzVaXQ0kVl5SAwYJGTAJDA0gC19UAA0IHAhFUQYt4F4CcB
                    clnt = HTTPClient.new()
                    res = clnt.get($1)
                    x = res.header['Location']
                    x == [] ? false : x[0]
                  when "youtube"
                    false
                  when "qq"
                    false
                  else
                    false
                  end

            # puts path + ":" + url if url

            #checksize = checkvideourl url if url
            #if checksize
              #downloadvideo url , path , checksize if url
              downloadvideo url , path , 10000 if url
              fetched = true
            #end
            break if fetched
           }
        }
        @fetching -= 1
      end
    }
    @fetching -= 1
  end

  def checkvideourl url

    check = false
    # puts "checkvideo url: #{url}"  if @debug
    begin
      http  = Net::HTTP.new(URI.parse(url).host)
      #res = http.request_head(URI.parse(url))
      res = http.request_head(url)
      if res['location']
        return checkvideourl res['location']
      else
        if res['content-length'].to_i > 1000
          check = res['content-length'].to_i
        else
          check = false
        end
      end
    rescue => ex
      puts ex.inspect + " url:#{url}"
      check = false
    end
    # puts "checkvideo url: #{url} check: #{check.to_s}"  if @debug
    return check
  end

  def downloadvideo url , path , size
    puts "downloadvideo : " + path

    downloaded = 0
    path = path.gsub("<u>","")
    pathmp4 = path.gsub(/flv$/,"mp4")
    if File.exists?(path) || File.exists?(path + ".mp4") || File.exists?(pathmp4)
      return
    end

    puts "download start: #{url} - #{path}"
    @downloads[path] = "start"
    fetched = false
    begin

      CrawlerLOGGER.info path

      open(M3UPath,"a") { |io| io.puts path }

      if @usecurl
        @fetching += 1
  
        if @ffmpeg
          puts "with ffmpeg"
          path2 = path.gsub(/flv$/,"mp4")
          gifpath = mkgifpath path
          # command = "curl -# -L '#{url}' | ffmpeg -i - -vcodec mpeg4 -r 23.976 -b 600k -ab 64k -acodec aac -strict experimental '#{path2}' &"
          # command = "curl -# -L '#{url}' | ffmpeg -threads 4 -y -i - -vcodec copy -acodec aac -strict experimental '#{path2}' &"
          command = "curl -# -L '#{url}' | ffmpeg -threads 4 -y -i - -vcodec copy -acodec copy '#{path2}' &"
          # command = " curl -# -L '#{url}' | ffmpeg -threads 4 -y -i - -vcodec copy -acodec copy '#{path2}' && ffmpeg -ss 10 -i '#{path2}' -t 2.5 -an -r 100 -s 160x90 -pix_fmt rgb24 -f gif '#{giffilename}'  &"
          puts command
          system command
          puts "¥@fetching -= 1"
          # p @queue
          @fetching -= 1
          # result = @db.execute(@sql_select,:name => (File.basename path2))
          # if resule.size == 0
            @db.execute(@sql,:name => (File.basename path2) ,:path => path2 )
          # end
          @downloads[path] = "complete"
        else
          command = "curl -# -L -R -o '#{path}' '#{url}' &"
          # result = @db.execute(@sql_select,:name => (File.basename path2))
          # if resule.size == 0
            @db.execute(@sql,:name => (File.basename path2) ,:path => path2 )
          # end
          puts command
          system command
          
          @fetching -= 1
          @downloads[path] = "complete"
        end
        return
      end

      command = "touch '#{path}'"
      system command

      @fetching += 1

      file = open(path, "w+b")
      http = EM::HttpRequest.new(url,:connect_timeout => 50)
        .get({:redirects => 10,:head => {"accept-encoding" => "gzip, compressed"}})

      http.errback {|client|
        @downloads[path] = "error"
        p "download error: #{path} #{client.inspect}";
        file.close
        @fetching -= 1
        command = "rm -f '#{path}'"
        system command
      }

      http.callback {
        file.close
        unless http.response_header.status == 200
          puts "failed with response code #{http.response_header.status}"
        end
        @downloads[path] = "complete"
        puts "download complete: #{path} "
        @fetching -= 1
        @queue.push({kind: JOB_CONVERT,value: path}) if @ffmpeg
        fetched = true
      }

      http.headers do |hash|
        p [:headers, hash]
      end

      http.stream do |chunk|
        downloaded += chunk.length
        puts "#{File.basename path} : #{chunk.length}" if @debug
        if size > 0
          @downloads[path] = "download #{(downloaded/MEGA).round}M / #{(size.to_f/MEGA).round}M #{(downloaded.to_f / size.to_f * 100.0).round(2)}%"
        end
        file.write chunk
      end

      # AGENT.pluggable_parser.default = Mechanize::Download
      # AGENT.get(url).save(path)
    rescue => ex
      p ex
      fetched = false
    end
    fetched
  end

  # convert
  def convert value
    command = "ffmpeg -i '#{value}' -vcodec mpeg4 -r 23.976 -b 600k  -ar 44100 -ab 64k -acodec aac -strict experimental '#{value2}'"
    puts command
    system command
    command = "rm -f '#{value}'"
    system command
  end

  def mkfilepath title,episode
    mkdirectory title
    episode = episode.gsub(/\[720p\]/,"").gsub("?","？")
    DOWNLOADDIR + "/" + title + "/" + episode + ".flv"
  end

  def mkdirectory title
    begin
      Dir.mkdir DOWNLOADDIR + "/" + title
    rescue => ex
    end
  end
  
  def mkgifpath path
    filename =  File.basename(path).gsub(/flv$/,"gif").gsub(/mp4$/,"gif")
    return "/var/smb/sdc1/video/tmp/" + filename
  end
  
end

# 最近のflvは中身をそのままで外装を変換するだけなのでコンバートまでしてしまう。
# Crawler.new(ffmpeg: false,debug: false,usecurl: true).run
Crawler.new(ffmpeg: true,debug: true,usecurl: true).run

