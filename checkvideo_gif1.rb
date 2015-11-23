#! /usr/bin/env ruby

def glob_flv
  filelist = []
  Dir.glob("/var/smb/sdc1/video/**/*.flv").each {|f|
    filelist << f
  }
  filelist
end

def glob_mp4
  filelist = []
  Dir.glob("/var/smb/sdc1/video/**/*.mp4").each {|f|
    filelist << f
  }
  filelist
end

def create_gif path
  begin
    giffilename = mkgifpath path
    command_ffmpeg = "ffmpeg -ss 10 -i '#{path}' -t 2.5 -an -r 100 -s 160x90 -pix_fmt rgb24 -f gif '#{giffilename}' & "
    command_ffmpeg = "ffmpeg -ss 10 -i '#{path}' -t 2.5 -an -r 100 -s 160x90 -pix_fmt rgb24 -f gif '#{giffilename}'  "
    system command_ffmpeg
  rescue => ex
    p ex
  end
end

def gifexists? path
  return File.exists? (mkgifpath path)
end

def mkgifpath path
  filename =  File.basename(path).gsub(/flv$/,"gif").gsub(/mp4$/,"gif")
  return "/var/smb/sdc1/video/tmp/" + filename
end


#---------------
# main

filelist = glob_flv + glob_mp4

filelist.sort.each{|path|
  create_gif path unless gifexists? path
}
