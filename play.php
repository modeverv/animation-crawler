<?php
$src = $_REQUEST["src"];
?>
<html lang="ja">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1.0"/>
<style>
body{background-color:#000;}
#main { position:absolute;top:0;height:100%;width:100%;left:0;z-index:-1 }
#video { position:absolute;top:0;height:100%;width:100%;left:0;z-index:-1 }
#menu { position:fixed;top:0;left:0;display:none;z-index:10; }
button {
  border-radius:5px;
  padding:10px;
  color:#fff;
  background:#405dca;
  text-align:center;
  text-decoration:none;
  margin:11px;
}
button:hover {
  background:#364ea5;
}
#menushow { position:fixed;top:0;left:0;height:100%;width:100%;z-index:10; }
#closebtn { margin-top:20px;}
#display {position:fixed;top:0;right:0;color:red;font-weight:bold;font-size:2em;display:none;z-index:10000;}
</style>
<script src="https://code.jquery.com/jquery-1.12.1.min.js"></script>
</head>
<body>
<div id="menushow"></div>
<div id="display"></div>

<div id="main">
  <video id="video" src="<?php echo $src; ?>"></video>
</div>

<div id="menu">
  <button id="closebtn">X</button>
  <button id="play">再生</button>
  <button id="stop">停止</button>
  <button id="to15">1.5倍速</button>
  <button id="to10">1.0倍速</button>
  <button id="plusS">+</button>
  <button id="minusS">-</button>
  <button id="skip90">90秒早送り</button>
  <button id="skip10">10秒早送り</button>
  <button id="rev10">10秒巻き戻し</button>
<!-- <button id="closewindow">閉じる</button> -->
</div>

<script>
$(function(){
var video = document.getElementById('video');

function play(){
  video.play();
}
function stop(){
  video.pause();
}

function to15(){
  video.playbackRate = 1.5;
  display("rate:" + myRound(video.playbackRate,1));
}

function to10(){
  video.playbackRate = 1.0;
  display("rate:" + myRound(video.playbackRate,1));
}

function plusS(){
  video.playbackRate += 0.1;
  display("rate:" + myRound(video.playbackRate,1));
}

function minusS(){
  video.playbackRate -= 0.1;
  display("rate:" + myRound(video.playbackRate,1));
}

function skip90(){
  video.currentTime += 90;
}

function skip10(){
  video.currentTime += 10;
}

function rev10(){
  video.currentTime -= 10;
}

function display(str){
    $("#display").html(str);
    $("#display").show(1);
    setTimeout(function(){
      $("#display").hide(1);
    },1000);
}

function myRound(val, precision) {
     digit = Math.pow(10, precision);
     val = val * digit;
     val = Math.round(val);
     val = val / digit;
     return val;
}

$("#play").on("click",play);
$("#stop").on("click",stop);
$("#to15").on("click",to15);
$("#to10").on("click",to10);
$("#plusS").on("click",plusS);
$("#minusS").on("click",minusS);
$("#skip90").on("click",skip90);
$("#skip10").on("click",skip10);
$("#rev10").on("click",rev10);
$("#closebtn").on("click",function(){
  $("#menu").hide();
  $("#menushow").show();
});
$("#closewindow").on("click",function(){
  if(confirm("閉じますか?")){
      //window.open('about:blank','_self').close();
      //$("#video-area").hide();
  }
});
$("#menushow").on("click touchstart",function(){
  $("#menu").show();
  $("#menushow").hide();
});
var resizer = function() {
    var height = $(document).height();
    var width = $(document).width();
    $("#video").css("height",height);
    $("#video").css("width",width);
};
resizer();
$(window).on("orientationchange resize",resizer);
$("#menushow").click();

});
</script>
</body>
</html>
