//
//  ViewController.swift
//  CCCHOOO
//
//  Created by virus1993 on 2018/1/23.
//  Copyright © 2018年 ascp. All rights reserved.
//

import Cocoa
import WebKit

class ViewController: NSViewController {
    @IBOutlet weak var webview: WKWebView!
    @IBOutlet weak var code: NSImageView!
    @IBOutlet weak var textField: NSTextField!
    let userController = WKUserContentController()
    var bullets = [WebBullet]()
    var bulletsIterator : IndexingIterator<[WebBullet]>?
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        userController.add(self, name: "fetchDlLink")
        webview.configuration.userContentController = userController
        webview.navigationDelegate = self
        
        loadSequenceBullet()
        
        webview.load(bullets.first!.request)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    @IBAction func uploadTextField(_ sender: Any) {
        let codeUpload = WebBullet(successAction: nil, failedAction: nil, method: .post, headFields: ["Referer":"http://www.ccchoo.com/file-38355.html",
                                                                                                     "Origin":"http://www.ccchoo.com",
                                                                                                    "Accept-Language":"zh-cn",
                                                                                                    "Upgrade-Insecure-Requests":"1",
                                                                                                    "Accept-Encoding":"gzip, deflate",
                                                                                                    "Content-Type":"application/x-www-form-urlencoded; charset=UTF-8",
                                                                                                    "X-Requested-With":"XMLHttpRequest",
                                                                                                    "Accept":"*/*",
                                                                                                    "User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_2) AppleWebKit/604.4.7 (KHTML, like Gecko) Version/11.0.2 Safari/604.4.7"],
                                  formData: ["action":"check_code",
                                             "code":textField.stringValue,
                                             "vipd":"0"],
                                  url: URL(string: "http://www.ccchoo.com/ajax.php")!,
                                  injectJavaScript: "var yyy=6;")
        bullets = [codeUpload]
        currentResult = codeUpload
        bulletsIterator = bullets.makeIterator()
        currentResult = bulletsIterator?.next()
        webview.load(currentResult!.request)
    }
    
    func loadSequenceBullet() {
        let mainPage = WebBullet(successAction: nil, failedAction: nil, method: .get, headFields: [:], formData: [:],
                                 url: URL(string: "http://www.ccchoo.com/down-38355.html")!,
                                 injectJavaScript: "var xxx=0;")
        
        let main2Page = WebBullet(successAction: nil, failedAction: nil, method: .get, headFields: ["Referer":"http://www.ccchoo.com/file-38355.html",
                                                                                                    "Accept-Language":"zh-cn",
                                                                                                    "Upgrade-Insecure-Requests":"1",
                                                                                                    "Accept-Encoding":"gzip, deflate",
                                                                                                    "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                                                                                    "User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_2) AppleWebKit/604.4.7 (KHTML, like Gecko) Version/11.0.2 Safari/604.4.7"],
                                 formData: [:],
                                 url: URL(string: "http://www.ccchoo.com/down2-38355.html")!,
                                 injectJavaScript: "var yyy=2;")
        let main3Page = WebBullet(successAction: {
            dat in
            guard let data = dat as? String else {
                print("no data!")
                return
            }
            
//            if let imageData = Data(base64Encoded: data), let img = NSImage(data: imageData) {
//                self.code.image = img
//            }
            print(data)
        }, failedAction: nil, method: .get, headFields: ["Referer":"http://www.ccchoo.com/down2-38355.html",
                                                                                                    "Accept-Language":"zh-cn",
                                                                                                    "Upgrade-Insecure-Requests":"1",
                                                                                                    "Accept-Encoding":"gzip, deflate",
                                                                                                    "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                                                                                    "User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_2) AppleWebKit/604.4.7 (KHTML, like Gecko) Version/11.0.2 Safari/604.4.7"],
                                  formData: [:],
                                  url: URL(string: "http://www.ccchoo.com/down-38355.html")!,
                                  injectJavaScript: "function getDowloadLink(){ return document.body.innerHTML.match(/http:\\/\\/down4\\.ccchoo\\.com[^\"]+\"/g)[0] } getDowloadLink();")
        //document.body.innerHTML.match(/http:\/\/down4\.ccchoo\.com[^"]+"/g)
        //function getBase64Image(img) { var canvas = document.createElement(\"canvas\"); canvas.width = img.width;canvas.height = img.height; var ctx = canvas.getContext(\"2d\"); ctx.drawImage(img, 0, 0, img.width, img.height); var dataURL = canvas.toDataURL(\"image/png\"); return dataURL.replace(\"data:image/png;base64,\", \"\");} getBase64Image(document.getElementById('imgcode'));
        
        bullets = [mainPage, main2Page, main3Page]
        currentResult = mainPage
        bulletsIterator = bullets.makeIterator()
        currentResult = bulletsIterator?.next()
    }
}

extension ViewController : WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        print("receive : \(message)")
    }
}

var currentResult : WebBullet?

extension ViewController : WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("finish load: \(navigation)")
        execNextCommand()
    }
    
    func execNextCommand() {
        DispatchQueue.global().async {
            if let result = currentResult {
                let sem = DispatchSemaphore(value: 0)
                DispatchQueue.main.async {
                    self.webview.evaluateJavaScript(result.injectJavaScript, completionHandler: { (data, err) in
                        if let e = err {
                            result.failedAction?(e)
                            print("error : \(e)")
                            sem.signal()
                            return
                        }
                        result.successAction?(data)
                        print("sucess : \(result.injectJavaScript)")
                        sem.signal()
                    })
                }
                sem.wait()
                currentResult = self.bulletsIterator?.next()
                if let result = currentResult {
                    DispatchQueue.main.async {
                        self.webview.load(result.request)
                    }
                }
            }
        }
    }
}
