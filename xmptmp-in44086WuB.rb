require 'pp'
require './uri.rb'
require 'eventmachine'
require 'em-http'
require 'nokogiri'
require 'open-uri'
require 'httpclient'
require 'mechanize'
require 'net/http'

class Crawler
  DOWNLOADDIR = "/var/smb/sdd1/video"
  
  START_URL = 'http://youtubeanisoku1.blog106.fc2.com/'
  AGENT  = Mechanize.new
  
  CONCURRENCY = 64
  WATCH_INTERVAL = 1

  JOB_ANISOKUTOP     = 'アニ速TOP'
  JOB_KOUSINPAGE     = '更新ページ'
  JOB_KOBETUPAGE     = '個別ページ'
  JOB_SAYMOVESEARCH  = 'saymove検索ページ'
  JOB_SAYMOVEVIDEO   = "saymoveビデオページ"
  JOB_NOSUBSEARCH    = "nosub検索ページ"
  JOB_NOSUBVIDEO     = "nosubビデオページ"
  JOB_CONVERT        = "flv2mp4"
  
  def initialize
    @queue = []
    @queue.push({ kind: JOB_ANISOKUTOP, value: START_URL })
    @fetching = 0
    @reachtoend = false
  end

  def run
    EM.run do
      EM.add_periodic_timer(WATCH_INTERVAL) do
       
        diff = CONCURRENCY - @fetching
        puts 'diff:' +  diff.to_s

        diff.times do
          job = @queue.pop
          unless job 
            @reachtoend = true
            break
          end

          process job
        end
        
        if @reachtoend && @fetching == 0
          puts "finish"
          EM::stop_event_loop
        else
          puts "reachtoend:#{@reachtoend.to_s} / fetching:#{@fetching}"
        end
      end
    end    
  end

  def process job
    puts "fetch +=1 #{job.inspect}"
    @fetching += 1
    case job[:kind]
    when JOB_ANISOKUTOP
      puts JOB_ANISOKUTOP
      anisokutop job[:value]
    when JOB_KOUSINPAGE
      anisokukousin job[:value]
    when JOB_KOBETUPAGE
      anisokukobetu job[:value]
    when JOB_SAYMOVESEARCH
      saymovesearch job[:value]
    when JOB_SAYMOVEVIDEO
      saymovevideo job[:value]
    when JOB_NOSUBSEARCH
      nosubsearch job[:value]
    when JOB_NOSUBVIDEO
      nosubvideo job[:value]
    when JOB_CONVERT
      convert job[:value]
    end
  end

  # anisoku top
  def anisokutop url
    req = EM::HttpRequest.new(url).get

    req.callback do
      page = Nokogiri::HTML(req.response)
      page.css(".Top_info div ul li a").each {|a|
        if a.attributes['title'].value =~ /更新状況/
          @queue.push({kind: JOB_KOUSINPAGE, value: a.attributes['href'].value })
        end
      }
      @fetching -= 1
    end    
  end

  # anisoku kousin
  def anisokukousin url
    req = EM::HttpRequest.new(url).get

    req.callback do
      page = Nokogiri::HTML(req.response)
      page.css(".article ul li a").each { |a|
        href = ""
        href = a.attributes["href"].value unless a.attributes["href"].nil?
        if href =~ /^http\:\/\/youtubeanisoku1\.blog106\.fc2\.com\/blog-entry-....\.html$/
          if a.attributes["title"]
            title = a.attributes["title"].value
          end
          if title
            puts title + "-" + href
            title = title.gsub(" ","",).gsub("/","").gsub("-","")
            @queue.push({kind: JOB_KOBETUPAGE, value: {title: title, href: href } })
          end
        end
      }
      @fetching -= 1
    end    
  end

  # anisoku kobetu
  def anisokukobetu value
    req = EM::HttpRequest.new(value[:href]).get

    req.callback do
      page = Nokogiri::HTML(req.response)
      page.css("a").each { |a|
        href = ""
        href = a.attributes["href"].value unless a.attributes["href"].nil?
        # http://say-move.org/comesearch.php?q=%E3%81%9D%E3%81%AB%E3%82%A2%E3%83%8B&sort=toukoudate&genre=&sitei=&mode=&p=1
        # http://www.nosub.tv/?s=%E3%81%9D%E3%81%AB%E3%82%A2%E3%83%8B
        #if href =~ /^http:\/\/say-move\.org\/comesearch.php/
        if href =~ /^http:\/\/www.nosub\.tv\/\?s=/
          puts value[:title] + "-" + href
          if value[:title] =~ /そにアニ/
            @queue.push({kind: JOB_NOSUBSEARCH, value: {title: value[:title], href: href } })
          end
        end
      }
      @fetching -= 1
    end    
  end

  # saymove search
  def saymovesearch value
    p value
    req = EM::HttpRequest.new(value[:href]).get

    req.callback do
      page = Nokogiri::HTML(req.response)
      urls = []
      page.css(".movtitle a").each { |a|
        href = ""
        href = a.attributes["href"].value unless a.attributes["href"].nil?
        p a.children[0].to_s
        episode = a.children[0].to_s.gsub(" ","").gsub("/","").gsub("　","").gsub("#","")
        puts value[:title] + "-" + episode + "-" + href
        urls << {title: value[:title] ,episode: episode, href: href }
      }
      @queue.push({kind: JOB_SAYMOVEVIDEO, value: urls })
      
      @fetching -= 1
    end    
  end

  # saymove video
  def saymovevideo value
    puts "saymovevideo" + value.inspect
    value.each do |val|
      @fetching += 1
      http200 = false
      req = EM::HttpRequest.new(val[:href]).get

      req.callback do       
        page = Nokogiri::HTML(req.response)
        page.css(".box02 input").each {|input|
          url = input.attribute("value")
          puts url
          path = mkfilepath val[:title],val[:episode]
          if File.exists? path
            next
          end
          begin
            command = "curl -# -L -R -o '#{path}' '#{url}'"
            puts command
            system command
            val[:path] = path
          rescue => ex
            p ex
          end
          
        }
        @fetching -= 1
      end
    end
    @fetching -= 1
  end

  def nosubsearch value
    urls = []
    
    req = EM::HttpRequest.new(value[:href]).get

    req.callback do
      page = Nokogiri::HTML(req.response)
      page.css(".title a[rel='bookmark']").each { |a|
        href = ""
        href = a.attributes["href"].value unless a.attributes["href"].nil?
        episode = a.attributes["title"].value
          .gsub(" ","").gsub("/","").gsub("　","").gsub("-","").gsub("#","")
        puts value[:title] + "-" + episode + "-" + href
        hash = {title: value[:title] ,episode: episode, href: href }
        urls << hash
      }
      @queue.push({kind: JOB_NOSUBVIDEO, value: urls })
      @fetching -= 1
    end
  end
  
  def nosubvideo value
    urls = []
    fetched = false
    value.each { |val|
      path = mkfilepath val[:title],val[:episode]
      
      if File.exists? path
        fetched = true
      end
      
      break if fetched
      
      @fetching += 1
      
      req = EM::HttpRequest.new(val[:href]).get

      req.callback do
        page = Nokogiri::HTML(req.response)
        videos = []
        page.css("script[type='text/javascript']").each { |script|
          next unless script.children[0] && script.children[0].to_s =~ /MukioPlayerURI/
          lines = script.children[0].to_s.gsub("\n","").split(";")
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
                    l =~ /file=(.*?)\\",/
                    #"type=video&file=http://www.nosub.tv/wp-content/plugins/mukiopress/lianyue/?/url/XBCAVbX1ZVVVUGXB1RTEYVRl9JGF9VUAUDUVUAGRdBHFhEAA4LEgRLWRZWFgkLSlwRA1pFGzVaXQ0kVl5SAwYJGTAJDA0gC19UAA0IHAhFUQYt4F4CcB&cid=ZGXVIHBFVJBl0HBlEBBwMFDVQBAQtWAAIGUlNVCVEFAF1UAAtUUFEsg783C93","360p(40MB)","",1);
                    #http://www.nosub.tv/wp-content/plugins/mukiopress/lianyue/?/url/XBCAVbX1ZVVVUGXB1RTEYVRl9JGF9VUAUDUVUAGRdBHFhEAA4LEgRLWRZWFgkLSlwRA1pFGzVaXQ0kVl5SAwYJGTAJDA0gC19UAA0IHAhFUQYt4F4CcB
                    u = "http://www.nosub.tv/wp-content/plugins/mukiopress/lianyue/?/url/#{$1}"
                    clnt = HTTPClient.new()
                    res = clnt.get(u)
                    x = res.header['Location']
                    x == [] ? false : x
                  when "youtube"
                    false
                  when "qq"
                    false
                  else
                    false
                  end
            check = checkvideo url if url
            if check
              downloadvideo url , path if url
              fetched = true
            end
            break if fetched
          }
        }
        @fetching -= 1        
      end
    }
    @fetching -= 1
  end
  
  def checkvideo url
    check = false
    puts "checkvideo url: #{url} check: #{check.to_s}"
    begin
      puts URI::VERSION
      http  = Net::HTTP.new(URI.parse(url).host)
      res = http.head(URI.parse(url).path)
      case res
      when Net::HTTPSuccess
        check = true 
      when Net::HTTPRedirection
        puts "checkvideo url: #{url} redirect: #{res['location']}"
        return checkvideo res['location']
      else
        check = false
      end
    rescue => ex
      puts ex.inspect + " url:#{url}"
      check = false
    end
    puts "checkvideo url: #{url} check: #{check.to_s}"
    return check
  end
  
  def downloadvideo url , path
    if File.exists? path
      return 
    end
    
    puts "download: #{url} - #{path}"
    fetched = false
    begin
      
      #AGENT.pluggable_parser.default = Mechanize::Download
      #AGENT.get(url).save(path)
      command = "touch '#{path}'"
      system command

      file = open(path, "w+b")
      http = EM::HttpRequest.new(url).get
      
      http.errback {
        p 'download error';
        file.close;
        @fetching -= 1
        command = "rm -f '#{path}'"
        system command
      }
      
      http.callback {
        file.close
        unless http.response_header.status == 200
          puts "Call failed with response code #{http.response_header.status}"
        end
        @fetching -= 1
        @queue.push({kind: JOB_CONVERT,value: path})
        fetched = true
      }

      http.headers do |hash|
        p [:headers, hash]
      end
      
      http.stream do |chunk|
        puts "#{path} : #{chunk}"
        file.write chunk
      end

      # command = "curl -L -R -o '#{path}' #{url}"
      # system command 
      
    rescue => ex
      p ex
      fetched = false
    end
    fetched 
  end
  

  # convert
  def convert value
    command = "ffmpeg -i '#{value}' -vcodec mpeg4 -r 23.976 -b 600k -acodec libfaac -ac 2 -ar 44100 -ab 128k '#{value}.mp4'"
    puts command
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

Crawler.new.run
