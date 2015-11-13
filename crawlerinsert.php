<?php
error_reporting(E_ALL);
error_reporting(0);

$msg = "";

dispatch();

function dispatch(){
    if(isset($_REQUEST["submit"])){
        $kind = $_REQUEST["submit"];
        if($kind == "insert"){
            insert();
        }
    }
}

function getDB(){
    $dsn = 'sqlite:/home/seijiro/crawler/crawler.db';
    $user = '';
    $pass = '';

    $dbh;
    try{
        $dbh = new PDO($dsn, $user, $pass,
                       array(
                           PDO::ERRMODE_EXCEPTION => true
                       )                       
        );
    }catch (PDOException $e){
        echo('Error:'.$e->getMessage());
        die();
    }
    return $dbh;
}

function insert(){
    global $msg;
    
    $pdo = getDB();
    try{
        $sql = "insert into crawler(name,path) values(:name,:path);";
        $stmt = $pdo->prepare($sql);
        $path = trim($_REQUEST["path"]);
        $name = basename($path);
        $ret = $stmt->execute(array(":name" => $name,":path" => $path));
        $msg = "insert ok.";
    }catch(Exception $e){
        $msg = $e->getMessage();
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
</head>
<body>
<div class="container">
  <h1>crawler insert</h1>
  <hr>
  <form method="post">
  <div>
    <div><?php echo $msg ?></div>
    <input class="col-xs-9 col-sm-9 col-md-9 col-lg-10" type="text" name="path" value=""/>
    <input class="btn btn-primary col-xs-3 col-sm-3 col-md-3 col-lg-2" type="submit" name="submit" value="insert"/>
  </div>
  </form>
</div>
</body>
</html>
