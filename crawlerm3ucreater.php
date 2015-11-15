<?php
error_reporting(0);

switch (true) {
    case !isset($_SERVER['PHP_AUTH_USER'], $_SERVER['PHP_AUTH_PW']):
    case $_SERVER['PHP_AUTH_USER'] !== 'admin':
    case $_SERVER['PHP_AUTH_PW']   !== 'test':
        header('WWW-Authenticate: Basic realm="Enter username and password."');
        header('Content-Type: text/plain; charset=utf-8');
        die('need login');
}
//header('Content-Type: text/html; charset=utf-8');

$info;

dispatch();

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
function convertPath($path){
    $p = str_replace(" ","%20",$path);
    $p = str_replace("/var/smb/sdc1/","http://seijiro:fuga@modeverv.aa0.netvolante.jp/",$p);
    $p = str_replace("/var/smb/sdb1/video","http://seijiro:fuga@modeverv.aa0.netvolante.jp/video2",$p);
    return $p;
}

function formatAndWrite($fh,$row){
    $path = $row['url'];
    fwrite($fh,"#EXTINF:1450," . $row["name"] . "\n");
    fwrite($fh,$path . "\n");
}

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

function normal(){
    global $info;
    $pdo = getDB();
    $sql = "select * from crawler order by id desc limit 100";
    $stmt = $pdo->prepare($sql);
    $stmt->execute();
    $info = convertRows($stmt->fetchAll(PDO::FETCH_ASSOC));
}

function convertRows($rows){
    $info = array();
    foreach($rows as $row){
        $row["url"] = convertPath($row["path"]);
        $info[] = $row;
    }
    return $info;
}

function find(){
    global $info;
    if(isset($_REQUEST["search"]) && $_REQUEST["search"] != ""){
        $pdo = getDB();
        $sql = "select * from crawler where name like :name order by name,id ";
        $stmt = $pdo->prepare($sql);
        $stmt->execute(array(":name" => "%".trim($_REQUEST["search"])."%"));
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
<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap.min.css" integrity="sha512-dTfge/zgoMYpP7QbHy4gWMEGsbsdZeCXz7irItjcC3sPUFtf0kuFbDz/ixG7ArTxmDjLXDmezHubeNikyKGVyQ==" crossorigin="anonymous">
<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap-theme.min.css" integrity="sha384-aUGj/X2zp5rLCbBxumKTCw2Z50WgIr1vs/PFN4praOTvYXWlVyh2UtNUU0KAUhAX" crossorigin="anonymous">
<script src="//ajax.googleapis.com/ajax/libs/jquery/1.11.1/jquery.min.js"></script>
<script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/js/bootstrap.min.js" integrity="sha512-K1qjQ+NcF2TYO/eI3M6v8EiNYZfA95pQumfvcVrTHtwQVDG+aHRqLi/ETn2uB+1JqwYqVG3LIvdm9lj6imS/pQ==" crossorigin="anonymous"></script>
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
</script>
</head>
<body>
<div class="container">
<h1>crawler m3u creater</h1>
<hr>
<form>
<div>
  <input class="col-xs-9 col-sm-9 col-md-9 col-lg-10" type="text" name="search" value="<?php echo isset($_REQUEST['search']) ? $_REQUEST['search'] : '' ?>"/>
  <input class="btn btn-primary col-xs-3 col-sm-3 col-md-3 col-lg-2" type="submit" name="submit" value="search"/>
</div>
<div>
  <!-- <button class="btn btn-primary" type="button" onclick="reload();return false;">reload</button> -->
  <!-- <button class="btn btn-primary" type="button" onclick="uncheck();return false;">uncheck all</button>-->
  <button class="btn btn-primary" type="button" onclick="location.href = 'anime.php';">reset</button>
  <input class="btn btn-warning" type="submit" name="submit" value="m3u"/>
</div>
<div>
<table id="maintable" class="col-xs-12 col-sm-12 col-md-12 col-lg-12 table table-hover table-bordered">
  <tr>
    <th></th>
    <th>title</th>
    <th>created_at</th>
    <th>link</th>
  </tr>
<?php foreach($info as $row) { ?>
  <tr>
    <td><input class="chk" id="chk<?php echo $row['id']?>" type="checkbox" name="ids[]" value="<?php echo $row['id']?>"/></td>
    <td onclick="prop(this)" data-value="chk<?php echo $row['id']?>"><?php echo $row["name"] ?></td>
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
