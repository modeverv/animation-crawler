# crawler animation

## config
modify DOWNLOADDIR in `crawler.rb`

    DOWNLOADDIR = "/var/smb/sdd1/video"
    
## usage
run script

    $ crawler.sh

## cron
    0 */6 *  *   *   /home/path/to/crawler/crawler.sh >> /home/path/to/crawler/crawler.log 2>&1

