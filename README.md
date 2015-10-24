# crawler animation

## config
modify DOWNLOADDIR in `crawler.rb`

    DOWNLOADDIR = "/var/smb/sdd1/video"
    
## usage
run script

    $ crawler.sh

## cron
    0 */6 *  *   *   /home/path/to/crawler/crawler.sh >> /home/path/to/crawler/crawler.log 2>&1

# changelog
2015/10/24 add function "store filepath to sqllite3" and web interface


