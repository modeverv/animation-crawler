# crawler animation
## config
modify DOWNLOADDIR in `crawler.rb`

    DOWNLOADDIR = "/var/smb/sdd1/video"
    
## usage
run script
    $ ruby create_db.rb
    $ chmod 777 ./crawler.db
    $ crawler.sh

## cron
    0 */6 *  *   *   /home/path/to/crawler/crawler.sh >> /home/path/to/crawler/crawler.log 2>&1

## web interface
### setup(sample)
    ln -s crawlerm3ucreate.php /var/www/html/anime.php
    
and config in php file's db place

    $dsn = 'sqlite:/path/to/crawler/crawler.db';

# changelog
2015/10/24 add function "store filepath to sqllite3" and web interface


