#! /bin/bash
echo $PATH
PATH=$PATH:/home/seijiro/.nvm/v0.8.4/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games
echo `date`
echo $PATH
cd /home/seijiro/crawler
# source /home/seijiro/.rvm/environments/ruby-2.0.0-p0@rails
PID=`ps x | grep -v grep | grep "cleanupvideo.rb" | awk '{ print $1 }'`
if [ x"$PID" != x"" ]; then
    kill -9 $PID
fi
bundle exec ruby -W0 cleanupvideo.rb
