function getDowloadLink(){ 
    return document.body.innerHTML.match(/http:\/\/down\w\.ccchoo\.com[^"]+/g)[0];
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

function getImageAndLink(){
  return {"image":getBase64Image(document.getElementById('imgcode')), "link":getDowloadLink()};
} 
