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
require 'capybara/poltergeist'
require 'capybara/webkit'
require 'headless'

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
  JOB_ANITANSEARCH   = "アニタン検索ページ"
  JOB_NOSUBSEARCH    = "nosub検索ページ"
  JOB_NOSUBVIDEO     = "nosubビデオページ"
  JOB_ANITANVIDEO    = "アニタンビデオページ"
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
    @_gaman = 600
    @gaman  = @_gaman
    @candidate = {}
    @title = {}
    @titles = {}
    @downloads = {}
    @urls = {}
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

    # Capybara.register_driver :poltergeist do |app|
    #   Capybara::Poltergeist::Driver.new(app, {:js_errors => true, :timeout => 5000 })
    # end
    Capybara::Webkit.configure do |config|
      # Enable debug mode. Prints a log of everything the driver is doing.
      config.debug = false
      config.allow_url("*")
    end
    Capybara.default_driver = :webkit
    Capybara.javascript_driver = :webkit
    Headless.new.start
    # @session = Capybara::Session.new(:poltergeist)
    @session = Capybara::Session.new(:webkit)

    # @session.driver.headers = {
    #   'User-Agent' => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/57.0.2987.133 Safari/537.36"
    # }
    @session.driver.header('user-agent', "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/57.0.2987.133 Safari/537.36")
    #puts html
    #doc = Nokogiri::HTML(html)
    #p doc.css("video").attribute["src"]
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
    when JOB_ANITANSEARCH
      sleep 0.5
      anitansearch job[:value]
    when JOB_NOSUBVIDEO
      sleep 0.6
      nosubvideo job[:value]
    when JOB_ANITANVIDEO
      sleep 0.6
      anitanvideo job[:value]
    when JOB_CONVERT
      convert job[:value]
    end
  end

  # anisoku top
  def anisokutop url
    req = EM::HttpRequest.new(url,:connect_timeout => 5000, :inactivity_timeout => 5000).get

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
    req = EM::HttpRequest.new(url,:connect_timeout => 5000, :inactivity_timeout => 5000).get

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

      if title =~ /更新状況/
        return
      end

      if title =~ /^.+$/
        title = title.gsub(":","").gsub('.','').gsub(" ","",).gsub("/","").gsub("#","").gsub("(","").gsub(")","")#.gsub("'","").gsub(/"/,"").gsub(/\<u\>/,"")
        if @title[title]
          #do nothing
          # puts "skip:" + title
        else
          if proseed title
            @title[title] = true
            # puts "do:" + title
            # CrawlerLOGGER.info "do:" + title
            if @urls[href]
              return
            end
            @urls[href] = :doing
            @queue.push({kind: JOB_KOBETUPAGE, value: {title: title, href: href } })
          end
        end
      end
    end
  end

  # anisoku kobetu
  def anisokukobetu value
    puts "anisokukobetu : " + value.to_s if @debug

    req = EM::HttpRequest.new(value[:href],:connect_timeout => 5000, :inactivity_timeout => 5000).get

    req.errback { @fetching -= 1 }

    req.callback do
      page = Nokogiri::HTML(req.response)
      unless page.title.nil?
      t = page.title.gsub(" ★ You Tube アニ速 ★","").strip
      t = t.gsub('.','').gsub(" ","",).gsub("/","").gsub("#","").gsub("(","").gsub(")","")#.gsub("'","").gsub(/"/,"").gsub(/\<u\>/,"")

      if t
        value[:title] = t
      end

      # puts t
      page.css("a").each { |a|
        href = ""
        href = a.attributes["href"].value unless a.attributes["href"].nil?
        # if href =~ /http:\/\/www.nosub\.tv/
        #   unless @titles[value[:title]]
        #     # puts value[:title] + "-" + href
        #     @titles[value[:title]] = :pedinding
        #     @queue.push({kind: JOB_NOSUBSEARCH, value: {title: value[:title], href: href } })
        #   end
        # end
          next unless href =~ /himado\.in\/\?s/
          next unless a.children[0].text =~ /「ひまわり」/
          next if @titles[value[:title]]
          # puts value[:title] + "-" + href
          @titles[value[:title]] = :pedinding
          @queue.push({kind: JOB_ANITANSEARCH, value: {title: value[:title], href: href } })
        }
        @fetching -= 1
      end
    end
  end

  def anitansearch value
    puts "himadosearch  : " + value.to_s #if @debug
    values = []
    value[:href] = value[:href].gsub("%WWW","WWW")

    begin
      open(value[:href]) {|io|
        page = Nokogiri::HTML(io.read)
        puts "in"
        page.css(".thumbtitle a[rel='nofollow']").each do |a|
          href = "http://himado.in"
          href += a.attributes["href"].value unless a.attributes["href"].nil?
          episode = a.attributes["title"].value.gsub('.','').gsub(" ","").gsub("/","").gsub("　","").gsub("#","").gsub(":","").gsub("第","").gsub("話","")#.gsub("(","").gsub(")","")#.gsub(/"/,"").gsub(/\<u\>/,"")
          puts value[:title] + "-" + episode + "-" + href
          unless episode =~ /アニメPV集/ || episode =~ /エヴァンゲリオン新劇場版：序/ || episode =~ /WitchHunterROBIN/
            hash = {title: value[:title] ,episode: episode, href: href }
            values << hash
          end
        end
        @queue.push({kind: JOB_ANITANVIDEO, value: values })
        @fetching -= 1
      }
    rescue => ex
      pp ex
    end

    return

    begin
      sleep 0.5
      req = EM::HttpRequest.new(value[:href],:connect_timeout => 5000, :inactivity_timeout => 5000).get
      req.headers do
        # pp req.response_header
      end
    rescue => ex
      p ex
    end

    req.errback { |client|
      @fetching -= 1
      pp "get error event machine : #{client.inspect}";
      puts "err #{value[:href]}"
    }

    req.callback do
      page = Nokogiri::HTML(req.response)
      # puts "in"
      page.css("#main a[rel='bookmark']").each do |a|
        href = ""
        href = a.attributes["href"].value unless a.attributes["href"].nil?
        episode = a.attributes["title"].value.gsub('.','').gsub(" ","").gsub("/","").gsub("　","").gsub("#","").gsub(":","")#.gsub("(","").gsub(")","")#.gsub(/"/,"").gsub(/\<u\>/,"")
        # puts value[:title] + "-" + episode + "-" + href
        unless episode =~ /アニメPV集/ || episode =~ /エヴァンゲリオン新劇場版：序/ || episode =~ /WitchHunterROBIN/
          hash = {title: value[:title] ,episode: episode, href: href }
          values << hash
        end
      end
      @queue.push({kind: JOB_ANITANVIDEO, value: values })
      @fetching -= 1
    end
  end

  def getURL type,line
    l = line
    url = case type
          when "fc2"
            return false
            l =~ /vid=(.*?)&/
            # puts "vid is #{$1}"
            u = "http://video.fc2.com/ginfo.php?mimi=d888f7517b875802cdce1e6d82e8b807&lang=ja&otag=1&tk=null&gk=null&v=#{$1}&upid=#{$1}"
            # puts "u is #{u}"
            x = false
            open(u) do |res|
              x = res.read.gsub("filepath=","")
            end
            # puts "x is #{x}"
            return false if x =~ /err_code/
            us = x.split("&")
            u = x[0]
            # puts "u is #{u}"
            hs = {}
            us = []
            if x.size > 2
              us = x[1..-1]
            end
            us.each do |e|
              kv = e.split("=")
              hs[kv[0]] = kv[1]
            end
            u = u + "?mid" + hs["mid"] + "&px-time" + hs["cdnt"] + "&px-hash=" + hs["cdnh"]
            u
          when "video"
            # puts "type = video; " * 20
            l =~ /file=(.*?)&/
            r302 = lambda do |url|
              # puts "url is #{url} "
              begin
              clnt = HTTPClient.new()
              res = clnt.get(url)
              x = res.header['Location']
              # puts "res.header is #{x}"
              p x
              if x == []
                return url
              else
                return x[0]
              end
              rescue => ex
                return false
              end
            end
            x = r302.call $1
          when "youtube"
            puts "youtube"
            false
          when "qq"
            puts "qq"
            false
          when "veoh"
            puts "veoh"
            false
          else
            puts $1
            puts "else"
            l =~ /file=(.*?)&/
            r302 = lambda do |url|
        # puts "url is #{url} "
        clnt = HTTPClient.new()
        x = []
        begin
          res = clnt.get(url)
          x = res.header['Location']
          # puts "res.header is "
          # p x
        rescue => ex
          p ex
        end
        if x == []
          return url
        else
          return x[0]
        end
      end
            x = r302.call $1
          end
    return url
  end

  def anitanvideo value
    puts "hiamdovideo  : " + value.to_s #if @debug

    urls = []

    value.each do |val|

      # puts value.to_s
      fetched = false
      path = mkfilepath val[:title],val[:episode]
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
         fetched = true
       end

       if @candidate[path]
         fetched = true
       end

       @candidate[path] = :pending

       if fetched
         # p "取得済み:" + val.inspect
         @fetching -= 1
         next
       end
       @fetching += 1

      url = false
      p val[:href]
      begin
        @session.visit val[:href]
        begin
          a = @session.find("video")["src"]
          url = URI.unescape(a)
        rescue => e1
          p e1
        end

        p url

        begin
          if url == false
            flashvars = @session.find("#playerswf")["flashvars"]
            flashvars =~ /'url='(.*)' sou/
            url_bare = $1
            url = URI.unescape(url_bare)
          end
        rescue => e2
          p e2
        end

        p url

        begin
          if url == false
            @session.execute_script "$('#movie_title').attr('src',ary_spare_sources.spare[1].src);"
            src = @session.find("#movie_title")["src"]
            url = URI.unescape(src)
          end
        rescue => e3
          p e3
        end

        downloadvideo(url, path, 10000) if url

      rescue => ex
        pp ex
      end
    end
    @fetching -= 1
  end

  def checkvideourl url

    check = false
    # puts "checkvideo url: #{url}"  if @debug
    begin
      begin
        clnt = HTTPClient.new()
        res = clnt.get(url)
        x = res.header['Location']
        if x == []
          url = url
        else
          url =  x[0]
        end
      rescue => ex
        p ex
      end

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
    # return
    if @downloads[path]
      return
    end

    @downloads[path] = :go

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

      # CrawlerLOGGER.info path

      # open(M3UPath,"a") { |io| io.puts path }

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
    t = title.gsub("(","（").gsub(")","）").gsub('.','').gsub(" ","").gsub("/","").gsub("　","").gsub("#","").gsub(":","").gsub("：","")#.gsub("(","").gsub(")","")#.gsub(/"/,"").gsub(/\<u\>/,"")
    t = t.gsub("！","!").gsub("+","＋")
    mkdirectory t
    episode = episode.gsub(/\[720p\]/,"").gsub("?","？")#.gsub("「","").gsub("」","")
    episode = episode.gsub(/高画質/,"").gsub(/QQ/,"").gsub("[","").gsub("]","").gsub("」","").gsub("「","").gsub("+","").gsub("(","（").gsub(")","）").gsub("！","!").gsub("+","")
    episode = episode.gsub("！","!")
    episode = episode.slice(0,60)
    DOWNLOADDIR + "/" + t + "/" + episode + ".flv"
  end

  def mkdirectory title
      Dir.mkdir DOWNLOADDIR + "/" + title
    rescue => ex
      p ex
  end

  def mkgifpath path
    filename =  File.basename(path).gsub(/flv$/,"gif").gsub(/mp4$/,"gif")
    return "/var/smb/sdc1/video/tmp/" + filename
  end

  def proseed title
    return true
    if title =~ /冴えない/
      return true
    else
      return false
    end
  end

end

# 最近のflvは中身をそのままで外装を変換するだけなのでコンバートまでしてしまう。
# Crawler.new(ffmpeg: false,debug: false,usecurl: true).run
Crawler.new(ffmpeg: true,debug: true,usecurl: true).run
