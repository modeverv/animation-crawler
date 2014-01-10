require 'eventmachine'
require 'em-http'
require 'nokogiri'
require 'open-uri'

class Crawler
  DOWNLOADDIR = "/var/smb/sdd1/video"
  
  START_URL = 'http://youtubeanisoku1.blog106.fc2.com/'
  
  CONCURRENCY = 164
  WATCH_INTERVAL = 1

  JOB_ANISOKUTOP = 'アニ速TOP'
  JOB_KOUSINPAGE = '更新ページ'
  JOB_KOBETUPAGE = '個別ページ'
  JOB_SAYMOVESEARCH = 'saymove検索ページ'
  JOB_SAYMOVEVIDEO = "saymoveビデオページ"
  JOB_VIDEODOWNLOAD = "ビデオダウンロード"
  
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

          p job
          process job
        end
        
        if @reachtoend && @fetching == 0
          puts "finish"
          EM::stop_event_loop
        end
      end
    end    
  end

  def process job
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
    when JOB_VIDEODOWNLOAD
      videodownload job[:value]
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
            title = title.gsub(" ","",).gsub("/","")
            @queue.push({kind: JOB_KOBETUPAGE, value: {title: title, href: href } })
          end
        end
      }
      @fetching -= 1
    end    
  end

  # anisoku kobetu
  def anisokukobetu value
    p value
    req = EM::HttpRequest.new(value[:href]).get

    req.callback do
      page = Nokogiri::HTML(req.response)
      page.css("a").each { |a|
        href = ""
        href = a.attributes["href"].value unless a.attributes["href"].nil?
        # http://say-move.org/comesearch.php?q=%E3%81%9D%E3%81%AB%E3%82%A2%E3%83%8B&sort=toukoudate&genre=&sitei=&mode=&p=1        
        if href =~ /^http:\/\/say-move\.org\/comesearch.php/
          puts value[:title] + "-" + href
          @queue.push({kind: JOB_SAYMOVESEARCH, value: {title: value[:title], href: href } })
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
        episode = a.children[0].to_s.gsub(" ","").gsub("/","").gsub("　","")
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

  # video download
  def videodownload value
    value.each do |val|
      p val
      path = mkfilepath val[:title],val[:episode]
      if File.exists? path
        next
      end
      begin
        command = "curl -# -L -R -o '#{path}' '#{val[:url]}'"
        puts command
        system command
      rescue => ex
        p ex
      end
    end
    @fetching -= 1
  end
  
  def mkfilepath title,episode
    begin 
      Dir.mkdir DOWNLOADDIR + "/" + title
    rescue => ex
    end
    DOWNLOADDIR + "/" + title + "/" + episode + ".flv"
  end
end

Crawler.new.run
