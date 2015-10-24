<?php
error_reporting(E_ALL);

dispatch();

function dispatch(){
    if(isset($_REQUEST["submit"])){
        $kind = $_REQUEST["submit"];
        if($kind == "m3u"){
            sendM3u();
        }
    }
}

function sendM3u(){
    /*
[32,
"新妹魔王の契約者BURST第03話「譲れない想いを君と」.flv",
"/var/smb/sdc1/video/新妹魔王の契約者BURST/新妹魔王の契約者BURST第03話「譲れない想いを君と」.flv",
"2015-10-24 12:49:37"]
#EXTM3U
#EXTINF:1450,おそ松さん03「こぼれ話集」.flv
/Volumes/smb/sdc1/video/おそ松さん/おそ松さん03「こぼれ話集」.flv
     */
    $ids = $_REQUEST["ids"];
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
        formatAndWrite($fh,$row);
    }
    fclose($fh);
    header('Content-Type:application/octet-stream');  //ダウンロードの指示
    header('Content-Disposition:filename=anime.m3u');  //ダウンロードするファイル名
    header('Content-Length:' . filesize($filename));   //ファイルサイズを指定
    readfile($filename);
    exit();
}
function formatAndWrite($fh,$row){
    fwrite($fh,"#EXTINF:1450," . $row["name"] . "\n");
    $path = str_replace("/var/","/Volumes/",$row["path"]);
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

function getInformations(){
    $pdo = getDB();
    $sql = "select * from crawler order by id desc limit 100";
    $stmt = $pdo->prepare($sql);
    $stmt->execute();
    $info = $stmt->fetchAll(PDO::FETCH_ASSOC);
    return $info;
}
$info = getInformations();
?>
<html>
<head>
<title>crawler m3u creater</title>
<style>
table,tr,td {
  border:1px solid;
}
</style>
</head>
<body>
<form>
<input type="submit" name="submit" value="m3u"/>
<table style="border:1px solid">
<?php foreach($info as $row) { ?>
<tr>
  <td><input type="checkbox" name="ids[]" value="<?php echo $row['id']?>" /></td>
  <td><?php echo $row["name"] ?></td>
  <td><?php echo $row["created_at"] ?></td>                            
</tr>
<?php }?>                               
</table>
</form>
</body>
</html>
