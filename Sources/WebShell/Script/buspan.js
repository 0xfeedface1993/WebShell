function readFileID() {
    var allHtml = selfHTML();
    var fileID = allHtml.match(/add\_ref\([\d]+\)/);
    if (fileID.length > 0) {
        return fileID[0].match(/\d+/)[0];
    }
    return "";
}

function selfHTML() {
    return document.body.innerHTML;
}
