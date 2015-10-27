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
  
  CONCURRENCY = 32
  WATCH_INTERVAL = 1
  MEGA = (1024 * 1024).to_f

  JOB_ANISOKUTOP     = 'アニ速TOP'
  JOB_KOUSINPAGE     = '更新ページ'
  JOB_KOBETUPAGE     = '個別ページ'
  JOB_NOSUBSEARCH    = "nosub検索ページ"
  JOB_NOSUBVIDEO     = "nosubビデオページ"
  JOB_CONVERT        = "flv2mp4"

  # constructor
  # hash[:ffmpeg] convert or not
  # hash[:debug] debug or not
  # hash[:usecurl] download by curl
  def initialize hash
    @queue = []
    @queue.push({ kind: JOB_ANISOKUTOP, value: START_URL })
    @fetching = 0
    @downloads = {}
    @ffmpeg = hash[:ffmpeg] || false
    @debug  = hash[:debug] || false
    @usecurl= hash[:usecurl]|| false
    @gaman  = 20
    @candidate = {}
    @title = {}
    @titles = {}
    @db = SQLite3::Database.new("crawler.db")
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
        
        if @fetching == 0
          @gaman -= 1
          print "fetching:#{@fetching} gaman:#{@gaman}\t"
          if @gaman == 0
            puts "finish"
            pp @downloads          
            EM::stop_event_loop
            @db.close
          end
        else
          print "fetching:#{@fetching}\t"
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
        if a.attributes['title']  && a.attributes['title'].value =~ /更新状況/
          @queue.push({kind: JOB_KOUSINPAGE, value: a.attributes['href'].value })
        end
      }
      @fetching -= 1
    end    
  end

  # anisoku kousin
  def anisokukousin url
    puts "anisokukousin : " + url
    req = EM::HttpRequest.new(url,:connect_timeout => 50).get

    req.errback { @fetching -= 1 }
    
    req.callback do
      page = Nokogiri::HTML(req.response)
      page.css("a").each { |a|
        href = ""
        href = a.attributes["href"].value unless a.attributes["href"].nil?
        if href =~ /^http\:\/\/youtubeanisoku1\.blog106\.fc2\.com\/blog-entry-....\.html$/
          if a.attributes["title"]
            title = a.attributes["title"].value
          end
          if title
            # puts title + "-" + href if @debug
            title = title.gsub('.','').gsub(" ","",).gsub("/","").gsub("#","")#.gsub("'","").gsub(/"/,"").gsub(/\<u\>/,"")
            if @title[title]
              #do nothing
              puts "skip:" + title
            else
              @title[title] = 1
              puts "do:" + title
              #if title =~ /アクエリオン/
                @queue.push({kind: JOB_KOBETUPAGE, value: {title: title, href: href } })
              #end
            end
          end
        end
      }
      @fetching -= 1
    end    
  end

  # anisoku kobetu
  def anisokukobetu value
    puts "anisokukobetu : " + value.to_s
    req = EM::HttpRequest.new(value[:href],:connect_timeout => 50).get

    req.errback { @fetching -= 1 }

    req.callback do
      page = Nokogiri::HTML(req.response)
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

  def nosubsearch value
    puts "nosubsearch  : " + value.to_s
    urls = []
    
    req = EM::HttpRequest.new(value[:href],:connect_timeout => 50).get
    
    req.errback { @fetching -= 1 }

    req.callback do
      page = Nokogiri::HTML(req.response)
      page.css(".title a[rel='bookmark']").each { |a|
        href = ""
        href = a.attributes["href"].value unless a.attributes["href"].nil?
        episode = a.attributes["title"].value
            .gsub('.','').gsub(" ","").gsub("/","").gsub("　","").gsub("#","").gsub(":","")#.gsub(/"/,"").gsub(/\<u\>/,"")
        # puts value[:title] + "-" + episode + "-" + href 
        unless episode =~ /アニメPV集/
          hash = {title: value[:title] ,episode: episode, href: href }
          urls << hash
        end
      }
      @queue.push({kind: JOB_NOSUBVIDEO, value: urls })
      @fetching -= 1
    end
  end
  
  def nosubvideo value
    puts "nosubvideo  : " + value.to_s
    
    urls = []
    fetched = false

    value.each { |val|
      path = mkfilepath val[:title],val[:episode]
      puts "before:" + path
      path = path.gsub("<u>","").gsub("'","").gsub(/"/,"")
      puts "after:" + path
      if File.exists?(path) || File.exists?(path + ".mp4")
        puts "already exists. #{path} "
        fetched = true
        @fetching -= 1
        return 
      end
      
      if @candidate[path]
        fetched = true
        @fetching -= 1
        return
      end

      @candidate[path] = :pending
      
      break if fetched
      
      @fetching += 1
      
      req = EM::HttpRequest.new(val[:href],:connect_timeout => 50).get

      req.errback { @fetching -= 1 }

      req.callback do
        #p req.response
        page = Nokogiri::HTML(req.response)
        videos = []
        page.css("script[type='text/javascript']").each { |script|
          p script.children[0]
          next unless script.children[0] && script.children[0].to_s =~ /MukioPlayerURI/
          lines = script.children[0].to_s.gsub("\n","").split(";")
          p lines
          lines.each {|l|
            next unless l =~ /addVideo/
            l =~ /type=(.*?)&/
            url = case $1
                  when "fc2"
                    #"type=fc2&vid=20140106PVrVWc2X&cid=msWVIDBFIbAghSVggCCFVpb0pjZFpWPQyIA19b10","360pFC2","",1);
                    l =~ /vid=(.*?)&/
                    u = "https://www.nosub.tv/wp-content/plugins/mukiopress//lianyue/?/fc2/#{$1}"
                    x = false
                    open(u) {|res| x = res.read }
                    x
                  when "video"
                    l =~ /file=(.*?)&/
                    puts "video find!! #{$1} #{path} " 
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

            puts path + ":" + url if url

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
    puts "checkvideo url: #{url}"  if @debug
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
    puts "checkvideo url: #{url} check: #{check.to_s}"  if @debug
    return check
  end
  
  def downloadvideo url , path , size
    base = (File.basename path)
    if base =~ /\[720p\]/
      return
    end
    puts "downloadvideo : " + path
    
    downloaded = 0
    path = path.gsub("<u>","")
    if File.exists?(path) || File.exists?(path + ".mp4")
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
          command = "curl -# -L '#{url}' | ffmpeg -i - -vcodec mpeg4 -r 23.976 -b 600k -ab 64k -acodec aac -strict experimental '#{path}.mp4' &"
        else
          command = "curl -# -L -R -o '#{path}' '#{url}' &"
        end
        puts command 
        system command 
        @fetching -= 1
        @downloads[path] = "complete"
        @db.execute(@sql,:name => (File.basename path) ,:path => path )
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
    command = "ffmpeg -i '#{value}' -vcodec mpeg4 -r 23.976 -b 600k  -ar 44100 -ab 64k -acodec aac -strict experimental '#{value}.mp4'"
    puts command
    system command
    command = "rm -f '#{value}'"
    system command
  end

  def mkfilepath title,episode
    mkdirectory title
    DOWNLOADDIR + "/" + title + "/" + episode + ".flv"
  end
  
  def mkdirectory title
    begin 
      Dir.mkdir DOWNLOADDIR + "/" + title
    rescue => ex
    end
  end
  
end

# 高速なサーバーならmp4に変換しておくほうがよいでしょう
Crawler.new(ffmpeg: false,debug: false,usecurl: true).run
