function loadImage() {
	var image = document.getElementById("imgcode");
	return getBase64Image(image);
}

function selfHTML() {
	return document.body.innerHTML;
}

function getBase64Image(img) {
    var canvas = document.createElement("canvas");
    canvas.width = img.width;
    canvas.height = img.height;
    var ctx = canvas.getContext("2d");
    ctx.drawImage(img, 0, 0, img.width, img.height);
    var dataURL = canvas.toDataURL("image/png");
    return dataURL.replace("data:image/png;base64,", "");
}
                                                                              
function getMiddleLink(){
	var link = document.querySelector("#addr_list>a.down_btn:last-of-type").href;
	return link;
}


function getFileName() {
    var name = document.querySelector('div.fb_l.f14.txtgray>.file_item>li');
  	name = name == null ? document.querySelector("div.row-fluid>div.span9>h1"):name;
  	name = name.innerText;
	return name;
}

var codeFlag = "bad";

function check_code(code){
	document.getElementById('s1').disabled = true;  
	$.post("ajax.php", "action=check_code&code=" + code,
		function(msg){
		 if(msg=='true'){
			document.getElementById('down_box').style.display ='';
			codeFlag = "good";
		 }else{
			document.getElementById('code_tips').innerHTML ='下载验证码不正确,请重新输入。';
			document.getElementById('code').value='';
			document.getElementById('s1').disabled =false;
			chg_imgcode();
			document.getElementById('code_tips').style.display='none';
		 }
	   });
}




