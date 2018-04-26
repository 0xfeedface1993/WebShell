function loginMyAccount() {
    uploginbox();
    document.getElementById("login_username").value = "318715498";
    document.getElementById("login_pwd").value = "xvtingsong";
    document.getElementById("loginsendbtn").click();
}

var downloadfilelink = "";

function fetchDownloadLink() {
    return downloadfilelink;
}

function selfHTML() {
    return document.body.innerHTML;
}

function selfCookie() {
    return document.cookie;
}

function getSecondPageLinkAndFileName() {
    var fileid = document.querySelector("span.bc2").getAttribute('onclick').split('\'')[1];
    var href = document.querySelector("div.col-md-4.col-sm-4.col-xs-12.down_five_main.down_five_rt>div.down_five_b>a").href;
    return { "fileName": getFileName(), "href": href, "fileid": fileid, "cookie": selfCookie() }
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
    var fileid = document.body.innerHTML.match(/svip_down\('[^']+/g)[0].split('\'')[1]
    vip_downvip_down('com', fileid);
    // getimgcoded();
    return { "img": getBase64Image(document.getElementById('verityImgtag')), "codeencry": codeencry, "fileid": fileid };
}

function getFileName() {
    var name = document.querySelector('.down_one_lf_tl>span').innerText;//document.querySelector('p.down_one_lf_tl>span').innerText;
    return uuid(8, 10) + name;
}

function uuid(len, radix) {
    var chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'.split('');
    var uuid = [],
        i;
    radix = radix || chars.length;

    if (len) {
        // Compact form
        for (i = 0; i < len; i++) uuid[i] = chars[0 | Math.random() * radix];
    } else {
        // rfc4122, version 4 form
        var r;

        // rfc4122 requires these characters
        uuid[8] = uuid[13] = uuid[18] = uuid[23] = '-';
        uuid[14] = '4';

        // Fill in random data. At i==19 set the high bits of clock sequence as
        // per rfc4122, sec. 4.1.5
        for (i = 0; i < 36; i++) {
            if (!uuid[i]) {
                r = 0 | Math.random() * 16;
                uuid[i] = chars[(i == 19) ? (r & 0x3) | 0x8 : r];
            }
        }
    }

    return uuid.join('');
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
