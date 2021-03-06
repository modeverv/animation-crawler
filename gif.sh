#! /bin/bash

echo "###START-gif###"
PATH=$PATH:/home/seijiro/.nvm/v0.8.4/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games
export PATH="/home/seijiro/.rvm/bin:$PATH" # Add RVM to PATH for scripting
source /home/seijiro/.rvm/environments/ruby-2.3.0
ruby -v
echo `date`
cd /home/seijiro/crawler
PID=`ps x | grep -v grep | grep "checkvideo_gif.rb" | awk '{ print $1 }'`
if [ x"$PID" != x"" ]; then
    kill -9 $PID
fi
bundle exec ruby -W0 checkvideo_gif.rb

echo "###END-gif###"
