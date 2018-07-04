var downloadfilelink = "";

function fetchDownloadLink() {
    return downloadfilelink;
}

function selfHTML() {
    return document.body.innerHTML;
}

function getSecondPageLinkAndFileName() {
    var fileid = document.scripts[1].innerHTML.match(/file_id=\d+/g)[0].split("=")[1];
    var href = document.querySelector(".doudbtn2").href;
    return { "fileName": getFileName(), "href": href, "fileid": fileid }
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

function getCodeImageAndCodeEncry() {
    var fileid = document.body.innerHTML.match(/vip_down\('[^']+/g)[0].split("'")[1];
    vip_downvip_down('com', fileid);
}

function getImageString() {
    return getBase64Image(document.getElementById('verityImgtag'));
}


function getFileName() {
    var name = document.querySelector('.down_one_lf_tl>span').innerText;
    return name;
}

function com_down(file_id, verycode, event) {
    var c1 = layer.load();
    $.ajax({
           type: 'post',
           url: 'ajax.php',
           data: 'action=load_down_addr_com&file_id=' + file_id + '&verycode=' + verycode + '&codeencry=' + codeencry,
           dataType: 'json',
           success: function(msg) {
           layer.close(c1);
           if (msg.status) {
                downloadfilelink = msg.str;
           }    else    {
                downloadfilelink = 'fetch download link failed: ' + msg.str;
           }
           },
           error: function() {}
           });
}
