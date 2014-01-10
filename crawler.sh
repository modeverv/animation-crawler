#! /bin/bash
cd /home/seijiro/crawler
source /home/seijiro/.rvm/environments/ruby-2.0.0-p0@rails
PID=`ps x | grep -v grep | grep "cwawler.rb" | awk '{ print $1 }'`
if [ x"$PID" != x"" ]; then
    kill -9 $PID
fi
bundle exec ruby crawler.rb
