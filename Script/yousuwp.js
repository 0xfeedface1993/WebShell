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
    return document.body.innerHTML.match(/<a id="dnode[^>]+>/g)[0].match(/[^"]\w+:\/\/[^"]+/g)[0];
}

function getDecode() {
    return document.getElementById('dform').children[0].value;
}

function getSubLinkAndDecode() {
    return {"decode": getDecode(), "link": getFileDownloadLink()};
}
