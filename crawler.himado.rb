# coding: utf-8
# frozen_string_literal: true

require 'pp'
require './uri.rb'
# require 'uri'
# modify uri module to permit '|'
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

# crawler
class Crawler
  DOWNLOADDIR = '/var/smb/sdc1/video'
  CrawlerLOGGER = Logger.new(
    DOWNLOADDIR +
    "/0log/download_#{Time.now.strftime('%Y%m%d')}.log"
  )
  M3UPath = DOWNLOADDIR + "/0m3u/#{Time.now.strftime('%Y%m%d')}.m3u"

  START_URL = 'http://youtubeanisoku1.blog106.fc2.com/'
  AGENT = Mechanize.new

  CONCURRENCY = 256 # 32
  WATCH_INTERVAL = 1
  MEGA = (1024 * 1024).to_f

  JOB_ANISOKUTOP     = 'アニ速TOP'
  JOB_KOUSINPAGE     = '更新ページ'
  JOB_KOBETUPAGE     = '個別ページ'
  JOB_ANITANSEARCH   = 'アニタン検索ページ'
  JOB_NOSUBSEARCH    = 'nosub検索ページ'
  JOB_NOSUBVIDEO     = 'nosubビデオページ'
  JOB_ANITANVIDEO    = 'アニタンビデオページ'
  JOB_CONVERT        = 'flv2mp4'
  JOB_DOWNLOADVIDEO  = 'download'

  DBFILE = 'crawler.db'

  # constructor
  # hash[:ffmpeg] convert or not
  # hash[:debug] debug or not
  # hash[:usecurl] download by curl
  def initialize(arghash)
    @queue = []
    @queue.push(kind: JOB_ANISOKUTOP, value: START_URL)
    @fetching = 0
    @downloads = {}
    @ffmpeg = arghash[:ffmpeg] || false
    # @debug  = arghash[:debug] || false
    @usecurl = arghash[:usecurl] || false
    @_gaman = 240
    @gaman  = @_gaman
    @candidate = {}
    @title = {}
    @titles = {}
    @downloads = {}
    @urls = {}
    @db = SQLite3::Database.new(DBFILE)
    sql = <<~SQL
      CREATE TABLE IF NOT EXISTS crawler(
        id integer primary key,
        name text,
        path text,
        created_at TIMESTAMP DEFAULT (DATETIME('now','localtime'))
      );
    SQL
    @db.execute sql
    @sql = <<~SQL
      insert into crawler(name,path) values(:name,:path)
    SQL
    @sql_select = <<~SQL
      select * from crawler where name = :name
    SQL

    Capybara::Webkit.configure do |config|
      config.debug = false
      config.allow_url('*')
    end
    Capybara.default_driver = :webkit
    Capybara.javascript_driver = :webkit
    Headless.new.start
    @session = Capybara::Session.new(:webkit)
    @session.driver.header(
      'user-agent',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/57.0.2987.133 Safari/537.36'
    )
  end

  def run
    EM.run do
      EM.add_periodic_timer(WATCH_INTERVAL) do
        diff = CONCURRENCY - @fetching

        diff.times do
          job = @queue.pop
          break unless job
          process job
        end

        if @queue.size.zero?
          @gaman -= 1
          print "fetching:#{@fetching} gaman:#{@gaman}\t"
          if @gaman.zero?
            puts :finish
            pp @downloads
            EM.stop_event_loop
            @db.close
          end
        else
          @gaman = @_gaman
          pp @downloads
        end
      end
    end
  end

  def process(job)
    case job[:kind]
    when JOB_ANISOKUTOP
      anisokutop job[:value]
    when JOB_KOUSINPAGE
      anisokukousin job[:value]
    when JOB_KOBETUPAGE
      anisokukobetu job[:value]
    when JOB_NOSUBSEARCH
      # sleep 0.5
      nosubsearch job[:value]
    when JOB_ANITANSEARCH
      # sleep 0.5
      anitansearch job[:value]
    when JOB_NOSUBVIDEO
      # sleep 0.6
      nosubvideo job[:value]
    when JOB_ANITANVIDEO
      # sleep 0.6
      anitanvideo job[:value]
    when JOB_CONVERT
      convert job[:value]
    when JOB_DOWNLOADVIDEO
      downloadvideo job[:value][:url], job[:value][:path], job[:value][:low]
    end
  end

  # anisoku top
  def anisokutop(url)
    req = EM::HttpRequest.new(
      url,
      connect_timeout: 5000, inactivity_timeout: 5000
    ).get

    req.errback { @fetching -= 1 }

    req.callback do
      page = Nokogiri::HTML(req.response)
      page.css('.Top_info div ul li a').each do |a|
        next unless a.attributes['title'] &&
                    a.attributes['title'].value =~ /更新状況/
        @queue.push(kind: JOB_KOUSINPAGE, value: a.attributes['href'].value)
      end
      @fetching -= 1
    end
  end

  # anisoku kousin
  def anisokukousin(url)
    # puts 'anisokukousin : ' + url
    req = EM::HttpRequest.new(
      url,
      connect_timeout: 5000, inactivity_timeout: 5000
    ).get

    req.errback { @fetching -= 1 }

    req.callback do
      page = Nokogiri::HTML(req.response)
      page.css('ul').each do |ul|
        next unless ul.attributes['type'] &&
                    ul.attributes['type'].value == 'square'
        ul.css('li a').each { |a| a2job a }
        @fetching -= 1
      end
    end
  end

  # a to job
  def a2job(a)
    href = ''
    href = a.attributes['href'].value unless a.attributes['href'].nil?
    return unless href =~ %r{^http\:\/\/youtubeanisoku1\.blog106\.fc2\.com\/blog-entry-.+?\.html$}

    title = a.attributes['title'].value if a.attributes['title']

    title = a.text unless title

    return if title =~ /更新状況/

    return unless title =~ /^.+$/

    title = title.delete(':').delete('.').delete(' ').delete('/')
    title = title.delete('#').delete('(').delete(')')
    return if @title[title]

    return unless proseed(title)

    @title[title] = true
    puts 'do:' + title
    return if @urls[href]
    @urls[href] = :doing
    @queue.push(kind: JOB_KOBETUPAGE, value: { title: title, href: href })
  end

  # anisoku kobetu
  def anisokukobetu(value)
    puts 'anisokukobetu : ' + value.to_s

    req = EM::HttpRequest.new(
      value[:href],
      connect_timeout: 5000, inactivity_timeout: 5000
    ).get

    req.errback { @fetching -= 1 }

    req.callback do
      page = Nokogiri::HTML(req.response)
      return if page.title.nil?
      t = page.title.delete(' ★ You Tube アニ速 ★').strip
      t = t.delete('.').delete(' ').delete('/').delete('#')
      t = t.delete('(').delete(')')

      value[:title] = t if t

      page.css('a').each do |a|
        href = ''
        href = a.attributes['href'].value unless a.attributes['href'].nil?
        next unless href =~ %r{himado\.in\/\?s}
        next unless a.children[0].text =~ /ひまわり/
        next if @titles[value[:title]]
        @titles[value[:title]] = :pedinding
        @queue.push(
          kind: JOB_ANITANSEARCH,
          value: { title: value[:title], href: href }
        )
      end
      @fetching -= 1
    end
  end

  def anitansearch(value)
    puts 'himadosearch  : ' + value.to_s # if @debug
    values = []
    value[:href] = value[:href].gsub('%WWW', 'WWW')

    begin
      req = EM::HttpRequest.new(
        value[:href],
        connect_timeout: 5000, inactivity_timeout: 5000
      ).get
    rescue => ex
      p ex
    end

    req.errback do |client|
      @fetching -= 1
      pp "get error event machine : #{client.inspect}"
      puts "err #{value[:href]}"
    end

    req.callback do
      page = Nokogiri::HTML(req.response)
      count = 2
      page.css(".thumbtitle a[rel='nofollow']").each do |a|
        break if count.negative?
        count -= 1
        href = 'http://himado.in'
        href += a.attributes['href'].value unless a.attributes['href'].nil?
        episode = a.attributes['title'].value.delete('.').delete(' ')
        episode = episode.delete('　').delete('#').delete(':').delete('第')
        episode = episode.delete('話').delete('/')
        unless episode =~ /アニメPV集/ || episode =~ /エヴァンゲリオン新劇場版：序/
          hash = { title: value[:title], episode: episode, href: href }
          values << hash
        end
      end
      @queue.push(kind: JOB_ANITANVIDEO, value: values)
      @fetching -= 1
    end
  end

  def anitanvideo(value)
    puts 'hiamdovideo  : ' + value.to_s # if @debug

    value.each do |val|
      fetched = false
      path = mkfilepath val[:title], val[:episode]
      path = path.delete('<u>').delete('\'')
      pathmp4 = path.gsub(/flv$/, 'mp4')

      targetpath = if File.exist?(path)
                     path
                   else
                     pathmp4
                   end

      if File.exist?(targetpath) && File.size(targetpath) > 1024 * 1024 * 2
        fetched = true
      end

      fetched = true if @candidate[path]

      @candidate[path] = :pending

      if fetched
        @fetching -= 1
        next
      end
      @fetching += 1

      url = false
      p val[:href]

      begin
        @session.visit val[:href]
        begin
          a = @session.find('video')['src']
          url = URI.unescape(a)
        rescue => e1
          p e1
        end

        begin
          if url == false
            flashvars = @session.find('#playerswf')['flashvars']
            flashvars =~ /'url='(.*?)' sou/
            url_bare = Regexp.last_match[1]
            url = URI.unescape(url_bare)
          end
        rescue => e2
          p e2
        end

        begin
          if url == false
            @session.execute_script '$(\'#movie_title\').attr(\'src\',ary_spare_sources.spare[1].src);'
            src = @session.find('#movie_title')['src']
            url = URI.unescape(src)
          end
        rescue => e3
          p e3
        end

        puts "enqueue #{path}"
        if url
          @queue.push(kind: JOB_DOWNLOADVIDEO,
                      value: { url: url, path: path, low: 10_000 })
        end
      rescue => ex
        pp ex
      end
    end
    @fetching -= 1
  end

  def downloadvideo(url, path, _size)
    puts 'downloadvideo : ' + path

    return if @downloads[path]

    @downloads[path] = :go

    path = path.delete('<u>')
    pathmp4 = path.gsub(/flv$/, 'mp4')

    if File.exist?(path) || File.exist?(path + '.mp4') || File.exist?(pathmp4)
      return
    end

    puts "download start: #{url} - #{path}"
    @downloads[path] = 'start'

    if @usecurl
      @fetching += 1
      if @ffmpeg
        path2 = path.gsub(/flv$/, 'mp4')
        command = "curl -# -L '#{url}' "
        command += '| ffmpeg -threads 4 -y -i - -vcodec copy -acodec copy '
        command += "'#{path2}' &"
        puts command
        system command
        @fetching -= 1
        @db.execute(@sql, name: (File.basename path2), path: path2)
      else
        command = "curl -# -L -R -o '#{path}' '#{url}' &"
        @db.execute(@sql, name: (File.basename path2), path: path2)
        puts command
        system command
        @fetching -= 1
      end
      @downloads[path] = 'complete'
    end
  rescue => ex
    p ex
  end

  def mkfilepath(title, episode)
    t = title.tr('(', '（').tr(')', '）').tr('.', '').tr(' ', '').tr('/', '')
    t = t.tr('　', '').delete('#').delete(':', '').delete('：', '')
    t = t.tr('！', '!').tr('+', '＋')
    mkdirectory t
    episode = episode.gsub(/\[720p\]/, '').tr('?', '？')
    episode = episode.gsub(/高画質/, '').gsub(/QQ/, '').delete('[').delete(']')
    episode = episode.delete('」').delete('「').delete('+').tr('(', '（')
    episode = episode.tr(')', '）').tr('！', '!')
    episode = episode.tr('！', '!').slice(0, 60)
    DOWNLOADDIR + '/' + t + '/' + episode + '.flv'
  end

  def mkdirectory(title)
    Dir.mkdir DOWNLOADDIR + '/' + title
  rescue => ex
    p ex
  end

  def mkgifpath(path)
    filename = File.basename(path).gsub(/flv$/, 'gif').gsub(/mp4$/, 'gif')
    '/var/smb/sdc1/video/tmp/' + filename
  end

  def proseed(title)
    true if title =~ /./
    # return true if title =~ /武装/ || title =~ /クラシカ/
    # return false
  end
end

# same content ffmpeg convert
# Crawler.new(ffmpeg: false,debug: false,usecurl: true).run
Crawler.new(ffmpeg: true, debug: true, usecurl: true).run
