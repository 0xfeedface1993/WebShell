//
//  Pan666.swift
//  CCCHOOO
//
//  Created by virus1993 on 2018/2/22.
//  Copyright © 2018年 ascp. All rights reserved.
//

import AppKit

extension ViewController {
    func load666PanSequence(urlString: String) {
        scriptName = "666pan"
        let main1Unit = InjectUnit(script: "\(functionScript) getFileName();", successAction: { (dat) in
            guard let name = dat as? String else {
                print("worong data!")
                return
            }
            print("fetch file name: \(name)")
            self.pan666Name = name
        }, failedAction: nil, isAutomaticallyPass: true)
        let main3Unit = InjectUnit(script: "\(functionScript) getImage();", successAction: { (dat) in
            guard let items = dat as? [String:String] else {
                print("worong data!")
                return
            }
            
            if let img = items["image"], let base64Data = Data(base64Encoded: img) {
                DispatchQueue.main.async {
                    self.code.image = NSImage(data: base64Data)
                }
            }
        }, failedAction: nil, isAutomaticallyPass: true)
        
        let main1Page = WebBullet(method: .get, headFields: ["Accept-Language":"zh-cn",
                                                             "Upgrade-Insecure-Requests":"1",
                                                             "Accept-Encoding":"gzip, deflate",
                                                             "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                                             "User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_3) AppleWebKit/604.5.6 (KHTML, like Gecko) Version/11.0.3 Safari/604.5.6"], formData: [:], url: pan6661URL, injectJavaScript: [main1Unit])
        let main2Page = WebBullet(method: .get, headFields: ["Accept-Language":"zh-cn",
                                                             "Upgrade-Insecure-Requests":"1",
                                                             "Accept-Encoding":"gzip, deflate",
                                                             "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                                             "User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_3) AppleWebKit/604.5.6 (KHTML, like Gecko) Version/11.0.3 Safari/604.5.6",
                                                             "Referer":pan6661URL.absoluteString], formData: [:], url: pan6662URL, injectJavaScript: [])
        let main3Page = WebBullet(method: .get, headFields: ["Accept-Language":"zh-cn",
                                                             "Upgrade-Insecure-Requests":"1",
                                                             "Accept-Encoding":"gzip, deflate",
                                                             "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                                             "User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_3) AppleWebKit/604.5.6 (KHTML, like Gecko) Version/11.0.3 Safari/604.5.6",
                                                             "Referer":pan6662URL.absoluteString], formData: [:], url: pan6663URL, injectJavaScript: [main3Unit])
        bullets = [main1Page, main2Page, main3Page]
        bulletsIterator = bullets.makeIterator()
        currentResult = bulletsIterator?.next()
        webview.load(currentResult!.request)
    }
    
    func reload666PanImagePage() {
        let main3Unit = InjectUnit(script: "\(functionScript) getImage();", successAction: { (dat) in
            guard let items = dat as? [String:String] else {
                print("worong data!")
                return
            }
            
            if let img = items["image"], let base64Data = Data(base64Encoded: img) {
                DispatchQueue.main.async {
                    self.code.image = NSImage(data: base64Data)
                }
            }
        }, failedAction: nil, isAutomaticallyPass: true)
        let main3Page = WebBullet(method: .get, headFields: ["Accept-Language":"zh-cn",
                                                             "Upgrade-Insecure-Requests":"1",
                                                             "Accept-Encoding":"gzip, deflate",
                                                             "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                                             "User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_3) AppleWebKit/604.5.6 (KHTML, like Gecko) Version/11.0.3 Safari/604.5.6",
                                                             "Referer":pan6662URL.absoluteString], formData: [:], url: pan6663URL, injectJavaScript: [main3Unit])
        bullets = [main3Page]
        bulletsIterator = bullets.makeIterator()
        currentResult = bulletsIterator?.next()
        webview.load(currentResult!.request)
    }
    
    func load666PanDownloadLink() {
        let codeVerifyUnit = InjectUnit(script: "\(functionScript) selfHTML();", successAction: { (dat) in
            guard let str = dat as? String, str == "true" else {
                print("worong data or worong paasword!")
                self.reload666PanImagePage()
                return
            }
        }, failedAction: nil, isAutomaticallyPass: true)
        let downloadListUnit = InjectUnit(script: "\(functionScript) getMiddleLink();", successAction: { (dat) in
            guard let str = dat as? String else {
                print("worong data!")
                return
            }
            print(str)
            self.readDownloadLink(url: URL(string: str)!)
        }, failedAction: nil, isAutomaticallyPass: true)
        let codeVerifyPage = WebBullet(method: .post, headFields: ["Referer":pan6663URL.absoluteString,
                                                                   "Accept-Language":"zh-cn",
                                                                   "Origin":"http://www.88pan.cc",
                                                                   "Accept":"*/*",
                                                                   "X-Requested-With":"XMLHttpRequest",
                                                                   "Content-Type":"application/x-www-form-urlencoded; charset=UTF-8",
                                                                   "Accept-Encoding":"gzip, deflate",
                                                                   "User-Agen":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_3) AppleWebKit/604.5.6 (KHTML, like Gecko) Version/11.0.3 Safari/604.5.6"], formData: ["action":"check_code", "code":self.textField.stringValue], url: URL(string: "http://www.88pan.cc/ajax.php")!, injectJavaScript: [codeVerifyUnit])
        let downloadListPage = WebBullet(method: .post, headFields: ["Connection":"keep-alive",
                                                                     "Referer":pan6663URL.absoluteString,
                                                                     "Accept-Language":"zh-cn",
                                                                     "Origin":"http://www.88pan.cc",
                                                                     "Accept":"text/plain, */*; q=0.01",
                                                                     "X-Requested-With":"XMLHttpRequest",
                                                                     "Content-Type":"application/x-www-form-urlencoded; charset=UTF-8",
                                                                     "Accept-Encoding":"gzip, deflate",
                                                                     "User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_3) AppleWebKit/604.5.6 (KHTML, like Gecko) Version/11.0.3 Safari/604.5.6",
                                                                     "Host":"www.88pan.cc"], formData: ["action":"load_down_addr2", "file_id":pan666FileNumber], url: URL(string: "http://www.88pan.cc/ajax.php")!, injectJavaScript: [downloadListUnit])
        
        bullets = [codeVerifyPage, downloadListPage]
        bulletsIterator = bullets.makeIterator()
        currentResult = bulletsIterator?.next()
        webview.load(currentResult!.request)
    }
    
    func readDownloadLink(url: URL) {
        let request = DownloadRequest(label: UUID().uuidString, fileName: self.pan666Name, downloadStateUpdate: nil, downloadFinished: { (tk) in
            guard let dat = tk.revData, let str = String.init(data: dat, encoding: .utf8) else {
                print("worong data!")
                return
            }
            print(str)
            do {
                let regx = try NSRegularExpression(pattern: "http://\\w+\\.\\w+.\\w+:\\w+/\\w+\\.php\\?[^\"]+", options: NSRegularExpression.Options.caseInsensitive)
                if let result = regx.firstMatch(in: str, options: .reportProgress, range: NSRange(location: 0, length: (str as NSString).length)) {
                    let link = (str as NSString).substring(with: result.range)
                    print(link)
                    if let urlx = URL(string: link) {
                        let label = UUID().uuidString
                        DownloadManager.share.add(request: DownloadRequest(label: label, fileName: self.pan666Name, downloadStateUpdate: { pack in
                            var items = self.DownloadStateController.content as! [DownloadInfo]
                            if let index = items.index(where: { $0.uuid == label }) {
                                items[index].progress = "\(pack.progress * 100)%"
                                items[index].totalBytes = "\(pack.totalBytes / 1024 / 1024)M"
                                items[index].site = pack.request.url.host!
                                self.DownloadStateController.content = items
                                return
                            }
                            let info = DownloadInfo()
                            info.uuid = label
                            info.name = self.pan666Name
                            info.progress = "\(pack.progress * 100)%"
                            info.totalBytes = "\(pack.totalBytes / 1024 / 1024)M"
                            info.site = pack.request.url.host!
                            items.append(info)
                            self.DownloadStateController.content = items
                        }, downloadFinished: { pack in
                            print(pack.revData?.debugDescription ?? "%%%%%%%%%%%%%%%%%%%%%% No data! %%%%%%%%%%%%%%%%%%%%%%")
                            if let data = pack.revData, let str = String(data: data, encoding: .utf8) {
                                print("%%%%%%%%%%%%%%%%%%%%%% data %%%%%%%%%%%%%%%%%%%%%%\n")
                                print(str)
                                print("%%%%%%%%%%%%%%%%%%%%%% data %%%%%%%%%%%%%%%%%%%%%%")
                            }
                            
                            if let urlString = NSSearchPathForDirectoriesInDomains(.downloadsDirectory, .userDomainMask, true).first {
                                let urly = URL(fileURLWithPath: urlString).appendingPathComponent(pack.request.fileName)
                                do {
                                    try pack.revData?.write(to: urly)
                                    print(">>>>>> file saved! <<<<<<")
                                } catch {
                                    print(error)
                                }
                            }
                        }, headFields: ["Referer":self.pan6663URL.absoluteString,
                                        "Accept-Language":"zh-cn",
                                        "Upgrade-Insecure-Requests":"1",
                                        "Accept-Encoding":"gzip, deflate",
                                        "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                        "User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_2) AppleWebKit/604.4.7 (KHTML, like Gecko) Version/11.0.2 Safari/604.4.7"], url: urlx, method: .get, body: nil))
                        let pasteBoard = NSPasteboard.general
                        pasteBoard.clearContents()
                        pasteBoard.writeObjects([link] as [NSPasteboardWriting])
                        print(">>>>>>>>> copy url done ! <<<<<<<<<")
                    }
                }
            }   catch   {
                print(error)
            }
            
        }, headFields: [:], url: url, method: .get, body: nil)
        DownloadManager.share.add(request: request)
    }
}

extension ViewController {
    
}
