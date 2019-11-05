function getBase64Image(img) {
    var canvas = document.createElement("canvas");
    canvas.width = img.width;
    canvas.height = img.height;
    var ctx = canvas.getContext("2d");
    ctx.drawImage(img, 0, 0, img.width, img.height);
    var dataURL = canvas.toDataURL("image/png");
    return dataURL.replace("data:image/png;base64,", "");
}
    
function getImage() {
    return getBase64Image(document.getElementById('imgcode'));
}

function getFileDownloadLink() {
    return document.querySelector("#addr_list>a[id^=\"dnode_\"]").getAttribute("data-url");  
}

function getDecode() {
    return document.getElementById('dform').children[0].value;
}

function getSubLinkAndDecode() {
    return {"decode": getDecode(), "link": getFileDownloadLink()};
}


function check_code(code){
    document.getElementById('s1').disabled =true;  
    $.post("ajax.php", "action=check_code&code=" + code,
        function(msg){
         if(msg=='true'){
            document.getElementById('down_box').style.display ='';
         }else{
            document.getElementById('code_tips').innerHTML ='下载验证码不正确,请重新输入。';
            document.getElementById('code').value='';
            document.getElementById('s1').disabled =false;
            chg_imgcode();
            document.getElementById('code_tips').style.display='none';
         }
       });
}

