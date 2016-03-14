#! /bin/bash
echo $PATH
PATH=$PATH:/home/seijiro/.nvm/v0.8.4/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games
export PATH="/home/seijiro/.rvm/bin:$PATH" # Add RVM to PATH for scripting
source /home/seijiro/.rvm/environments/ruby-2.3.0
ruby -v
echo `date`
echo $PATH
cd /home/seijiro/crawler
# source /home/seijiro/.rvm/environments/ruby-2.0.0-p0@rails
bundle exec ruby -W0 checkvideo_gif.rb

