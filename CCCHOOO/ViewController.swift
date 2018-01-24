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
    let fileNumber = "50044"
    var downloadLink : URL?
    lazy var functionScript : String = {
        if let file = Bundle.main.url(forResource: "ccchooo", withExtension: "js") {
            do {
                let str = try String(contentsOf: file)
                return str
            }   catch {
                print(error)
                return ""
            }
        }
        return ""
    }()
    
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
        //http://www.ccchoo.com/file-51406.html
        let codeUpload = WebBullet(successAction: {
            dat in
            if let url = self.downloadLink {
                DownloadManager.share.add(request: DownloadRequest(label: "test", fileName: "dragdemo.zip", downloadStateUpdate: { pack in
                    print("--------- name: \(pack.request.fileName)\n--------- progress: \(pack.progress)")
                }, downloadFinished: { pack in
                    print(pack.revData?.debugDescription ?? "%%%%%%%%%%%%%%%%%%%%%% No data! %%%%%%%%%%%%%%%%%%%%%%")
                    if let data = pack.revData, let str = String(data: data, encoding: .utf8) {
                        print("%%%%%%%%%%%%%%%%%%%%%% data %%%%%%%%%%%%%%%%%%%%%%\n")
                        print(str)
                        print("%%%%%%%%%%%%%%%%%%%%%% data %%%%%%%%%%%%%%%%%%%%%%")
                    }
                }, headFields: ["Referer":"http://www.ccchoo.com/down-\(self.fileNumber).html",
                    "Accept-Language":"zh-cn",
                    "Upgrade-Insecure-Requests":"1",
                    "Accept-Encoding":"gzip, deflate",
                    "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                    "User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_2) AppleWebKit/604.4.7 (KHTML, like Gecko) Version/11.0.2 Safari/604.4.7"], url: url))
                let pasteBoard = NSPasteboard.general
                pasteBoard.clearContents()
                pasteBoard.writeObjects([self.downloadLink!.absoluteString] as [NSPasteboardWriting])
                print(">>>>>>>>> copy url done ! <<<<<<<<<")
            }
        }, failedAction: nil, method: .post, headFields: ["Referer":"http://www.ccchoo.com/file-\(fileNumber).html",
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
                                  injectJavaScript: "")
        bullets = [codeUpload]
        currentResult = codeUpload
        bulletsIterator = bullets.makeIterator()
        currentResult = bulletsIterator?.next()
        webview.load(currentResult!.request)
    }
    
    func loadSequenceBullet() {
        let mainPage = WebBullet(successAction: nil, failedAction: nil, method: .get, headFields: [:], formData: [:],
                                 url: URL(string: "http://www.ccchoo.com/down-\(fileNumber).html")!,
                                 injectJavaScript: "")
        
        let main2Page = WebBullet(successAction: nil, failedAction: nil, method: .get, headFields: ["Referer":"http://www.ccchoo.com/file-\(fileNumber).html",
                                                                                                    "Accept-Language":"zh-cn",
                                                                                                    "Upgrade-Insecure-Requests":"1",
                                                                                                    "Accept-Encoding":"gzip, deflate",
                                                                                                    "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                                                                                    "User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_2) AppleWebKit/604.4.7 (KHTML, like Gecko) Version/11.0.2 Safari/604.4.7"],
                                 formData: [:],
                                 url: URL(string: "http://www.ccchoo.com/down2-\(fileNumber).html")!,
                                 injectJavaScript: "")
        let main3Page = WebBullet(successAction: {
            dat in
            guard let dic = dat as? [String:String] else {
                print("no data!")
                return
            }
            
            if let url = URL(string: dic["link"] ?? "") {
                self.downloadLink = url
                print("link: \(url.absoluteString)")
            }
            
            if let base64 = dic["image"], let data = Data(base64Encoded: base64), let img = NSImage(data: data) {
                self.code.image = img
            }
        }, failedAction: nil, method: .get, headFields: ["Referer":"http://www.ccchoo.com/down2-\(fileNumber).html",
                                                                                                    "Accept-Language":"zh-cn",
                                                                                                    "Upgrade-Insecure-Requests":"1",
                                                                                                    "Accept-Encoding":"gzip, deflate",
                                                                                                    "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                                                                                    "User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_2) AppleWebKit/604.4.7 (KHTML, like Gecko) Version/11.0.2 Safari/604.4.7"],
                                  formData: [:],
                                  url: URL(string: "http://www.ccchoo.com/down-\(fileNumber).html")!,
                                  injectJavaScript: "\(functionScript) getImageAndLink();")
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
    
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        print("+++++++++++++++++++++ didReceiveServerRedirectForProvisionalNavigation +++++++++++++++++++++")
        print(navigation.debugDescription)
        print("+++++++++++++++++++++ didReceiveServerRedirectForProvisionalNavigation +++++++++++++++++++++")
    }
}

var currentResult : WebBullet?

extension ViewController : WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("finish load: \(navigation.debugDescription)")
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
