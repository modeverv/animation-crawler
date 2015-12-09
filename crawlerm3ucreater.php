<?php
error_reporting(0);
setlocale(LC_ALL, "ja_JP.utf8");

// basic auth
switch (true) {
    case !isset($_SERVER['PHP_AUTH_USER'], $_SERVER['PHP_AUTH_PW']):
    case $_SERVER['PHP_AUTH_USER'] !== 'admin':
    case $_SERVER['PHP_AUTH_PW']   !== 'test':
        header('WWW-Authenticate: Basic realm="Enter username and password."');
        header('Content-Type: text/plain; charset=utf-8');
        die('need login');
}

$info; // contains data which used for display

dispatch();

/**
 * dispatcher
 */
function dispatch(){
    if(isset($_REQUEST["submit"])){
        $kind = $_REQUEST["submit"];
        if($kind == "m3u"){
            sendM3u();
        }
        if($kind == "search"){
            find();
        }
    }else{
        normal();
    }
}

/**
 * @return is smartphone or not. when smartphone, return true;
 */
function isSmartPhone(){
    return false;
    $ua = $_SERVER['HTTP_USER_AGENT'];
    if ((strpos($ua, 'Android') !== false) && (strpos($ua, 'Mobile') !== false) || (strpos($ua, 'iPhone') !== false) || (strpos($ua, 'Windows Phone') !== false)) {
        return true;
    }
    return false;
}

/**
 * sned M3U file for media player
 */
function sendM3u(){
    /*
    [32,
    "新妹魔王の契約者BURST第03話「譲れない想いを君と」.flv",
    "/var/smb/sdc1/video/新妹魔王の契約者BURST/新妹魔王の契約者BURST第03話「譲れない想いを君と」.flv",
    "2015-10-24 12:49:37"]
    =>
    #EXTM3U
    #EXTINF:1450,おそ松さん03「こぼれ話集」.flv
    /Volumes/smb/sdc1/video/おそ松さん/おそ松さん03「こぼれ話集」.flv
    =>
    http://seijiro:fuga@modeverv.aa0.modeverv.aa0.netvolante.jp/video/
     */
    $ids = $_REQUEST["ids"];
    if(count($ids) == 0){
        return normal();
    }
    $pdo = getDB();
    $sql = "select * from crawler where id = :id ";
    $stmt = $pdo->prepare($sql);
    $filename = "crawler.m3u";
    $fh = fopen($filename,"w");
    fwrite($fh,"#EXTM3U\n");
    foreach($ids as $id){
        $stmt->execute(array(":id" => $id));
        $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $row = $results[0];
        $row["url"] = convertPath($row["path"]);
        formatAndWrite($fh,$row);
    }
    fclose($fh);
    header('Content-Type:application/octet-stream');  //ダウンロードの指示
    header('Content-Disposition:filename=anime.m3u');  //ダウンロードするファイル名
    header('Content-Length:' . filesize($filename));   //ファイルサイズを指定
    readfile($filename);
    unlink($filename);
    exit();
}

/**
 * conver filepath to accessible url
 */
function convertPath($path){
    $p = str_replace(" ","%20",$path);
    $p = str_replace("/var/smb/sdc1/","http://seijiro:fuga@modeverv.aa0.netvolante.jp/",$p);
    $p = str_replace("/var/smb/sdb1/video","http://seijiro:fuga@modeverv.aa0.netvolante.jp/video2",$p);
    return $p;
}

/**
 * convert filepath to accessible gif url
 */
function convertGif($path){
    /*
    $gif = str_replace("mp4","gif",$path);
    $gif = str_replace("flv","gif",$gif);
    $gif = str_replace("avi","gif",$gif);
    $gif = str_replace("mkv","gif",$gif);
    $gif = str_replace("rmvb","gif",$gif);
    $gif = "/var/smb/sdc1/video/gif/" . basename($gif);
    $base64 = "data:image/gif;base64," . base64_encode(file_get_contents($gif));
    return $base64;
    */
    $base = basename($path);
    $gif = str_replace("mp4","gif",$base);
    $gif = str_replace("flv","gif",$gif);
    $gif = str_replace("avi","gif",$gif);
    $gif = str_replace("mkv","gif",$gif);
    $gif = str_replace("rmvb","gif",$gif);
    $p = str_replace(" ","%20",$gif);
    $p = "http://seijiro:fuga@modeverv.aa0.netvolante.jp/video/gif/" . $p;
    return $p;
}

/**
 * write file along right format
 */
function formatAndWrite($fh,$row){
    $path = $row['url'];
    fwrite($fh,"#EXTINF:1450," . $row["name"] . "\n");
    fwrite($fh,$path . "\n");
}

/**
 * get DB connection(PDO)
 */
function getDB(){
    $dsn = 'sqlite:/home/seijiro/crawler/crawler.db';
    $user = '';
    $pass = '';

    $dbh;
    try{
        $dbh = new PDO($dsn, $user, $pass);
    }catch (PDOException $e){
        echo('Error:'.$e->getMessage());
        die();
    }
    return $dbh;
}

/**
 * modify table record 
 */
function convertRows($rows){
    $info = array();
    foreach($rows as $row){
        $row["url"] = convertPath($row["path"]);
        $row["gif"] = convertGif($row["path"]);
        $info[] = $row;
    }
    return $info;
}

/**
 * function that dispay normal page called by dispatch
 */
function normal(){
    global $info;
    $pdo = getDB();
    $sql = "select * from crawler order by id desc limit 150";
    $stmt = $pdo->prepare($sql);
    $stmt->execute();
    $info = convertRows($stmt->fetchAll(PDO::FETCH_ASSOC));
}

/**
 * function that search called by dispatch
 */
function find(){
    global $info;
    if(isset($_REQUEST["search"]) && $_REQUEST["search"] != ""){
        $pdo = getDB();
        $sql = "select * from crawler where path like :path order by name,id desc";
        $stmt = $pdo->prepare($sql);
        $stmt->execute(array(":path" => "%".trim($_REQUEST["search"])."%"));
        $info = convertRows($stmt->fetchAll(PDO::FETCH_ASSOC));
     }else{
        normal();
    }
}
?>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<meta name="apple-mobile-web-app-capable" content="yes"/>    
<title>crawler m3u creater</title>
<link rel="stylesheet" href="//maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap.min.css" integrity="sha512-dTfge/zgoMYpP7QbHy4gWMEGsbsdZeCXz7irItjcC3sPUFtf0kuFbDz/ixG7ArTxmDjLXDmezHubeNikyKGVyQ==" crossorigin="anonymous">
<link rel="stylesheet" href="//maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap-theme.min.css" integrity="sha384-aUGj/X2zp5rLCbBxumKTCw2Z50WgIr1vs/PFN4praOTvYXWlVyh2UtNUU0KAUhAX" crossorigin="anonymous">
<script src="//ajax.googleapis.com/ajax/libs/jquery/1.11.1/jquery.min.js"></script>
<style>
.lazy { border-radius:5px; }
</style>
<script>
/*!
 * Lazy Load - jQuery plugin for lazy loading images
 *
 * Copyright (c) 2007-2015 Mika Tuupola
 *
 * Licensed under the MIT license:
 *   http://www.opensource.org/licenses/mit-license.php
 *
 * Project home:
 *   http://www.appelsiini.net/projects/lazyload
 *
 * Version:  1.9.7
 *
 */

(function($, window, document, undefined) {
    var $window = $(window);

    $.fn.lazyload = function(options) {
        var elements = this;
        var $container;
        var settings = {
            threshold       : 0,
            failure_limit   : 0,
            event           : "scroll",
            effect          : "show",
            container       : window,
            data_attribute  : "original",
            skip_invisible  : false,
            appear          : null,
            load            : null,
            placeholder     : "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsQAAA7EAZUrDhsAAAANSURBVBhXYzh8+PB/AAffA0nNPuCLAAAAAElFTkSuQmCC"
        };

        function update() {
            var counter = 0;

            elements.each(function() {
                var $this = $(this);
                if (settings.skip_invisible && !$this.is(":visible")) {
                    return;
                }
                if ($.abovethetop(this, settings) ||
                    $.leftofbegin(this, settings)) {
                        /* Nothing. */
                } else if (!$.belowthefold(this, settings) &&
                    !$.rightoffold(this, settings)) {
                        $this.trigger("appear");
                        /* if we found an image we'll load, reset the counter */
                        counter = 0;
                } else {
                    if (++counter > settings.failure_limit) {
                        return false;
                    }
                }
            });

        }

        if(options) {
            /* Maintain BC for a couple of versions. */
            if (undefined !== options.failurelimit) {
                options.failure_limit = options.failurelimit;
                delete options.failurelimit;
            }
            if (undefined !== options.effectspeed) {
                options.effect_speed = options.effectspeed;
                delete options.effectspeed;
            }

            $.extend(settings, options);
        }

        /* Cache container as jQuery as object. */
        $container = (settings.container === undefined ||
                      settings.container === window) ? $window : $(settings.container);

        /* Fire one scroll event per scroll. Not one scroll event per image. */
        if (0 === settings.event.indexOf("scroll")) {
            $container.bind(settings.event, function() {
                return update();
            });
        }

        this.each(function() {
            var self = this;
            var $self = $(self);

            self.loaded = false;

            /* If no src attribute given use data:uri. */
            if ($self.attr("src") === undefined || $self.attr("src") === false) {
                if ($self.is("img")) {
                    $self.attr("src", settings.placeholder);
                }
            }

            /* When appear is triggered load original image. */
            $self.one("appear", function() {
                if (!this.loaded) {
                    if (settings.appear) {
                        var elements_left = elements.length;
                        settings.appear.call(self, elements_left, settings);
                    }
                    $("<img />")
                        .bind("load", function() {

                            var original = $self.attr("data-" + settings.data_attribute);
                            $self.hide();
                            if ($self.is("img")) {
                                $self.attr("src", original);
                            } else {
                                $self.css("background-image", "url('" + original + "')");
                            }
                            $self[settings.effect](settings.effect_speed);

                            self.loaded = true;

                            /* Remove image from array so it is not looped next time. */
                            var temp = $.grep(elements, function(element) {
                                return !element.loaded;
                            });
                            elements = $(temp);

                            if (settings.load) {
                                var elements_left = elements.length;
                                settings.load.call(self, elements_left, settings);
                            }
                        })
                        .attr("src", $self.attr("data-" + settings.data_attribute));
                }
            });

            /* When wanted event is triggered load original image */
            /* by triggering appear.                              */
            if (0 !== settings.event.indexOf("scroll")) {
                $self.bind(settings.event, function() {
                    if (!self.loaded) {
                        $self.trigger("appear");
                    }
                });
            }
        });

        /* Check if something appears when window is resized. */
        $window.bind("resize", function() {
            update();
        });

        /* With IOS5 force loading images when navigating with back button. */
        /* Non optimal workaround. */
        if ((/(?:iphone|ipod|ipad).*os 5/gi).test(navigator.appVersion)) {
            $window.bind("pageshow", function(event) {
                if (event.originalEvent && event.originalEvent.persisted) {
                    elements.each(function() {
                        $(this).trigger("appear");
                    });
                }
            });
        }

        /* Force initial check if images should appear. */
        $(document).ready(function() {
            update();
        });

        return this;
    };

    /* Convenience methods in jQuery namespace.           */
    /* Use as  $.belowthefold(element, {threshold : 100, container : window}) */

    $.belowthefold = function(element, settings) {
        var fold;

        if (settings.container === undefined || settings.container === window) {
            fold = (window.innerHeight ? window.innerHeight : $window.height()) + $window.scrollTop();
        } else {
            fold = $(settings.container).offset().top + $(settings.container).height();
        }

        return fold <= $(element).offset().top - settings.threshold;
    };

    $.rightoffold = function(element, settings) {
        var fold;

        if (settings.container === undefined || settings.container === window) {
            fold = $window.width() + $window.scrollLeft();
        } else {
            fold = $(settings.container).offset().left + $(settings.container).width();
        }

        return fold <= $(element).offset().left - settings.threshold;
    };

    $.abovethetop = function(element, settings) {
        var fold;

        if (settings.container === undefined || settings.container === window) {
            fold = $window.scrollTop();
        } else {
            fold = $(settings.container).offset().top;
        }

        return fold >= $(element).offset().top + settings.threshold  + $(element).height();
    };

    $.leftofbegin = function(element, settings) {
        var fold;

        if (settings.container === undefined || settings.container === window) {
            fold = $window.scrollLeft();
        } else {
            fold = $(settings.container).offset().left;
        }

        return fold >= $(element).offset().left + settings.threshold + $(element).width();
    };

    $.inviewport = function(element, settings) {
         return !$.rightoffold(element, settings) && !$.leftofbegin(element, settings) &&
                !$.belowthefold(element, settings) && !$.abovethetop(element, settings);
     };

    /* Custom selectors for your convenience.   */
    /* Use as $("img:below-the-fold").something() or */
    /* $("img").filter(":below-the-fold").something() which is faster */

    $.extend($.expr[":"], {
        "below-the-fold" : function(a) { return $.belowthefold(a, {threshold : 0}); },
        "above-the-top"  : function(a) { return !$.belowthefold(a, {threshold : 0}); },
        "right-of-screen": function(a) { return $.rightoffold(a, {threshold : 0}); },
        "left-of-screen" : function(a) { return !$.rightoffold(a, {threshold : 0}); },
        "in-viewport"    : function(a) { return $.inviewport(a, {threshold : 0}); },
        /* Maintain BC for couple of versions. */
        "above-the-fold" : function(a) { return !$.belowthefold(a, {threshold : 0}); },
        "right-of-fold"  : function(a) { return $.rightoffold(a, {threshold : 0}); },
        "left-of-fold"   : function(a) { return !$.rightoffold(a, {threshold : 0}); }
    });

})(jQuery, window, document);
</script>
<script src="//maxcdn.bootstrapcdn.com/bootstrap/3.3.5/js/bootstrap.min.js" integrity="sha512-K1qjQ+NcF2TYO/eI3M6v8EiNYZfA95pQumfvcVrTHtwQVDG+aHRqLi/ETn2uB+1JqwYqVG3LIvdm9lj6imS/pQ==" crossorigin="anonymous"></script>
<script>
function uncheck(){
    $(".chk").prop("checked",false);
}
function prop(elem){
    var chk_id = $(elem).data("value");
    var id = "#" + chk_id;
    $(id).prop("checked",!$(id).prop("checked"));
}
function reload(){
    location.reload(true);
}
$(function(){
    $("img.lazy").lazyload({effect : "fadeIn"});
});
</script>
</head>
<body>
<div class="container">
<h1>crawler m3u creater</h1>
<hr>
<form>
<div>
  <input class="col-xs-8 col-sm-8 col-md-8 col-lg-8" type="text" name="search" value="<?php echo isset($_REQUEST['search']) ? $_REQUEST['search'] : '' ?>"/>
  <input style="margin-top:-4px" class="btn btn-primary col-xs-offset-1 col-xs-3 col-sm-offset-1 col-sm-3 col-md-offset-1 col-md-3 col-lg-offset-1 col-lg-2" type="submit" name="submit" value="search"/>
</div>
<div>
  <!-- <button class="btn btn-primary" type="button" onclick="reload();return false;">reload</button> -->
  <!-- <button class="btn btn-primary" type="button" onclick="uncheck();return false;">uncheck all</button>-->
  <button class="btn btn-primary" type="button" onclick="location.href = 'anime.php';">reset</button>
  <input class="btn btn-warning" type="submit" name="submit" value="m3u"/>
</div>
<div>
<table id="maintable" class="col-xs-12 col-sm-12 col-md-12 col-lg-12 table table-hover table-bordered" style="margin-top:5px;">
  <tr>
    <th></th>
    <th>title</th>
    <th>created_at</th>
    <th>link</th>
  </tr>
<?php foreach($info as $row) { ?>
  <tr>
    <td onclick="prop(this)" data-value="chk<?php echo $row['id']?>"><input class="chk" id="chk<?php echo $row['id']?>" type="checkbox" name="ids[]" value="<?php echo $row['id']?>"/></td>
    <td onclick="prop(this)" data-value="chk<?php echo $row['id']?>"><?php if(!isSmartPhone()){ ?><img data-original="<?php echo $row['gif'] ?>" alt="gif" class="lazy" style="width:160px;height:90px"/><br/><?php } ?><?php echo $row["name"] ?></td>
    <td onclick="prop(this)" data-value="chk<?php echo $row['id']?>"><?php echo $row["created_at"] ?></td>
    <td><a href="<?php echo $row['url'] ?>" target="_blank">video</a></td>
  </tr>
<?php }?>
</table>
</div>
</form>
</div>
</body>
</html>
