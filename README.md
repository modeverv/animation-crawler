# crawler

## config
modify DOWNLOADDIR in `crawler.rb`

    DOWNLOADDIR = "/var/smb/sdd1/video"
    
## usage
    crawler.sh

## cron
    0 */6 *  *   *   /home/path/to/crawler/crawler.sh >> /home/seijiro/path/to/crawler/crawler.log 2>&1

