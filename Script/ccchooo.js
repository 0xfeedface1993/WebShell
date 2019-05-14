function getDowloadLink() {
    var results = document.querySelector('#addr_list0>.bc').href;
    return results != null ? results:"";
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

function getImageAndLink() {
    var code = document.getElementById('imgcode');
    var imgx = "";
    if (code != null) {
        imgx = getBase64Image(code);
    }
    var link = getDowloadLink();
    return { "image": imgx, "link": (link != null ? link : "") };
}

function getFileName() {
                                                                      var x = document.getElementsByClassName('down_one_lf_tl');
                                                                      if (x != null && x.length > 0) {
                                                                      if (x[0].children.length > 0) {
                                                                      var name = x[0].children[0].innerText;
                                                                      return name;
                                                                      }
                                                                      return "";
                                                                      }
    
    return "";
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
