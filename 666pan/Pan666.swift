//
//  Pan666.swift
//  CCCHOOO
//
//  Created by virus1993 on 2018/2/22.
//  Copyright © 2018年 ascp. All rights reserved.
//

#if os(macOS)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

/// 666盘，提供下载首页地址即可
public class Pan666 : WebRiffle {
    override var scriptName: String {
        return "666pan"
    }
    
    /// 文件名，从页面获取
    var fileName = ""
    /// 文件ID
    var fileNumber = ""
    /// 首页，因为会出现重定向的问题，先写死，后期解决这个问题
    var pan6661URL : URL {
        return URL(string: "http://www.88pan.cc/file-\(fileNumber).html")!
    }
    /// 中转页面，重定向问题
    var pan6662URL : URL {
        return URL(string: "http://www.88pan.cc/down2-\(fileNumber).html")!
    }
    /// 验证码输入页面，重定向问题
    var pan6663URL : URL {
        return URL(string: "http://www.88pan.cc/down-\(fileNumber).html")!
    }
    
    /// 初始化
    ///
    /// - Parameter urlString: 下载首页地址
    public init(urlString: String) {
        super.init()
        mainURL = URL(string: urlString)
        /// 从地址中截取文件id
        let regx = try? NSRegularExpression(pattern: "\\d{5,}", options: NSRegularExpression.Options.caseInsensitive)
        let strNS = urlString as NSString
        if let result = regx?.firstMatch(in: urlString, options: NSRegularExpression.MatchingOptions.reportProgress, range: NSRange(location: 0, length: strNS.length)) {
            fileNumber = strNS.substring(with: result.range)
            print("fileNumber: \(fileNumber)")
        }
    }
    
    override public func begin() {
        load666PanSequence()
    }
    
    /// 启动序列
    func load666PanSequence() {
        let main1Unit = InjectUnit(script: "\(functionScript) getFileName();", successAction: { (dat) in
            guard let name = dat as? String else {
                print("worong data!")
                return
            }
            print("fetch file name: \(name)")
            self.fileName = name
        }, failedAction: nil, isAutomaticallyPass: true)
        let main3Unit = InjectUnit(script: "\(functionScript) getImage();", successAction: { (dat) in
//            guard let items = dat as? [String:String], let img = items["image"], let base64Data = Data(base64Encoded: img), let image = NSImage(data: base64Data) else {
//                print("worong data!")
//                return
//            }
//
//            DispatchQueue.main.async {
//                self.show(verifyCode: image, confirm: { (code) in
//                    self.load666PanDownloadLink(code: code)
//                }, reloadWay: { (imageView) in
//                    self.reload666PanImagePage()
//                }, withRiffle: self)
//            }
            self.load666PanDownloadLink(code: "1234")
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
        webView.load(currentResult!.request)
    }
    
    
    /// 重新获取验证码，暂时不需要
    func reload666PanImagePage() {
        let main3Unit = InjectUnit(script: "\(functionScript) getImage();", successAction: { (dat) in
//            guard let items = dat as? [String:String], let img = items["image"], let base64Data = Data(base64Encoded: img), let image = NSImage(data: base64Data) else {
//                print("worong data!")
//                return
//            }
//
//            DispatchQueue.main.async {
//                if let promot = self.promotViewController {
//                    promot.codeView.imageView.image = image
//                }   else    {
//                    self.show(verifyCode: image, confirm: { (code) in
//                        self.load666PanDownloadLink(code: code)
//                    }, reloadWay: { (imageView) in
//                        self.reload666PanImagePage()
//                    }, withRiffle: self)
//                }
//            }
            self.load666PanDownloadLink(code: "1234")
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
        webView.load(currentResult!.request)
    }
    
    
    /// 获取下载中转地址，非真实下载地址
    ///
    /// - Parameter code: 验证码文本，目前验证码可以是错误的
    func load666PanDownloadLink(code: String) {
        let codeVerifyUnit = InjectUnit(script: "\(functionScript) selfHTML();", successAction: { (dat) in
            guard let str = dat as? String, str == "true" else {
                print("worong data or worong paasword! but can download!")
//                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1, execute: {
//                    self.reload666PanImagePage()
//                })
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
                                                                   "Origin":"http://\(pan6663URL.host!)",
            "Accept":"*/*",
            "X-Requested-With":"XMLHttpRequest",
            "Content-Type":"application/x-www-form-urlencoded; charset=UTF-8",
            "Accept-Encoding":"gzip, deflate",
            "User-Agen":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_3) AppleWebKit/604.5.6 (KHTML, like Gecko) Version/11.0.3 Safari/604.5.6"], formData: ["action":"check_code", "code":code], url: URL(string: "http://\(pan6663URL.host!)/ajax.php")!, injectJavaScript: [codeVerifyUnit])
        let downloadListPage = WebBullet(method: .post, headFields: ["Connection":"keep-alive",
                                                                     "Referer":pan6663URL.absoluteString,
                                                                     "Accept-Language":"zh-cn",
                                                                     "Origin":"http://\(pan6663URL.host!)",
            "Accept":"text/plain, */*; q=0.01",
            "X-Requested-With":"XMLHttpRequest",
            "Content-Type":"application/x-www-form-urlencoded; charset=UTF-8",
            "Accept-Encoding":"gzip, deflate",
            "User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_3) AppleWebKit/604.5.6 (KHTML, like Gecko) Version/11.0.3 Safari/604.5.6",
            "Host":pan6663URL.host!], formData: ["action":"load_down_addr2", "file_id":fileNumber], url: URL(string: "http://\(pan6663URL.host!)/ajax.php")!, injectJavaScript: [downloadListUnit])
        
        bullets = [codeVerifyPage, downloadListPage]
        bulletsIterator = bullets.makeIterator()
        currentResult = bulletsIterator?.next()
        webView.load(currentResult!.request)
    }
    
    
    /// 获取下载地址，666盘的下载地址不能从webview里面取，实际上返回的是一个js代码，会延时跳转到实际下载地址，所以要用下载功能下载页面并做字符串截取获取地址
    ///
    /// - Parameter url: 下载地址中转页面
    func readDownloadLink(url: URL) {
        let request = DownloadRequest(label: UUID().uuidString, fileName: self.fileName, downloadStateUpdate: nil, downloadFinished: { (tk) in
            guard let dat = tk.revData, let str = String(data: dat, encoding: .utf8) else {
                print("worong data!")
                return
            }
            print("+++++ Parser string success: \(str)")
            
            do {
                let regx = try NSRegularExpression(pattern: "http://\\w+\\.\\w+.\\w+:\\w+/\\w+\\.php\\?[^\"]+", options: NSRegularExpression.Options.caseInsensitive)
                if let result = regx.firstMatch(in: str, options: .reportProgress, range: NSRange(location: 0, length: (str as NSString).length)) {
                    let link = (str as NSString).substring(with: result.range)
                    print("++++++ find download link: \(link)")
                    
                    guard let urlx = URL(string: link) else {
                        print("+++++ Link not url string: \(link)")
                        self.downloadFinished()
                        return
                    }
                    
                    let label = UUID().uuidString
                    self.fileDownloadRequest = DownloadRequest(label: label, fileName: self.fileName, downloadStateUpdate: { pack in
                        #if os(macOS)
                            guard let controller = self.downloadStateController else {   return  }
                            var items = controller.content as! [DownloadInfo]
                            if let index = items.index(where: { $0.uuid == label }) {
                                items[index].progress = "\(pack.progress * 100)%"
                                items[index].totalBytes = "\(Float(pack.totalBytes) / 1024.0 / 1024.0)M"
                                items[index].site = pack.request.url.host!
                                controller.content = items
                                return
                            }
                            items.append(DownloadInfo(task: pack))
                            controller.content = items
                        #elseif os(iOS)
                            print("((((((((((((((((((((((((( Post UpdateRiffleDownloadNotification )))))))))))))))))))))))))))))")
                            NotificationCenter.default.post(name: WebRiffle.UpdateRiffleDownloadNotification, object: Pipeline.share.downloadStateData)
                        #endif
                    }, downloadFinished: { pack in
                        print(pack.revData?.debugDescription ?? "%%%%%%%%%%%%%%%%%%%%%% No data! %%%%%%%%%%%%%%%%%%%%%%")
                        if let data = pack.revData, let str = String(data: data, encoding: .utf8) {
                            print("%%%%%%%%%%%%%%%%%%%%%% data %%%%%%%%%%%%%%%%%%%%%%\n")
                            print(str)
                            print("%%%%%%%%%%%%%%%%%%%%%% data %%%%%%%%%%%%%%%%%%%%%%")
                        }
                        
                        defer {
                            self.downloadFinished()
                        }
                        
                        // 保存到下载文件夹下
//                        if let urlString = NSSearchPathForDirectoriesInDomains(.downloadsDirectory, .userDomainMask, true).first {
//                            let urly = URL(fileURLWithPath: urlString).appendingPathComponent(pack.request.fileName)
//                            do {
//                                try pack.revData?.write(to: urly)
//                                print(">>>>>> file saved! <<<<<<")
//                            } catch {
//                                print(error)
//                            }
//                        }
                        FileManager.default.save(pack: pack)
                    }, headFields: ["Referer":self.pan6663URL.absoluteString,
                                    "Accept-Language":"zh-cn",
                                    "Upgrade-Insecure-Requests":"1",
                                    "Accept-Encoding":"gzip, deflate",
                                    "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                    "User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_2) AppleWebKit/604.4.7 (KHTML, like Gecko) Version/11.0.2 Safari/604.4.7"], url: urlx, method: .get, body: nil)
                    DownloadManager.share.add(request: self.fileDownloadRequest!)
                }
            }   catch   {
                print(error)
            }
            
        }, headFields: [:], url: url, method: .get, body: nil)
        DownloadManager.share.add(request: request)
    }
}
