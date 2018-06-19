//
//  Yousuwp.swift
//  WebShellExsample
//
//  Created by virus1993 on 2018/5/11.
//  Copyright © 2018年 ascp. All rights reserved.
//

#if os(macOS)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

class Yousuwp: PCWebRiffle {
    override var scriptName: String {
        return "yousuwp"
    }
    
    struct PageURL {
        var rule: ((String) -> URL)
        var fileID = ""
        var url: URL {
            return rule(fileID)
        }
        
        init(rule: @escaping ((String) -> URL)) {
            self.rule = rule
        }
        
        static let file = PageURL(rule: { id in return URL(string: "http://www.yousuwp.com/file-\(id).html")! })
        static let down2 = PageURL(rule: { id in return URL(string: "http://www.yousuwp.com/down2-\(id).html")! })
        static let down = PageURL(rule: { id in return URL(string: "http://www.yousuwp.com/down-\(id).html")! })
    }
    
    var fileID = ""
    
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
            fileID = strNS.substring(with: result.range)
            print("-------- fileID: \(fileID)")
            host = .yousuwp
        }
    }
    
    override public func begin() {
        loadWebView()
        loadYousuwpSequence()
    }
    
    /// 启动序列
    func loadYousuwpSequence() {
        var file = PageURL.file
        file.fileID = fileID
        var down2 = PageURL.down2
        down2.fileID = fileID
        var down = PageURL.down
        down.fileID = fileID
        
        let main3Unit = InjectUnit(script: "\(functionScript)", successAction: { (data) in
//            guard let image = data as? String, let base64Data = Data(base64Encoded: image), let img = NSImage(data: base64Data) else {
//                print("worong data!")
//                return
//            }
            
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
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1, execute: {
                self.seat?.webView.evaluateJavaScript("getSubLinkAndDecode();", completionHandler: { (datx, err) in
                    guard let items = datx as? [String : String] else {
                        print("****** Data not dictionary!")
                        return
                    }
                    
                    guard let string = items["link"] else {
                        print("****** Link not found!")
                        return
                    }
                    
                    guard let decode = items["decode"] else {
                        print("****** Decode not found!")
                        return
                    }
                    
                    let url = URL(string: string)
                    self.loadDownloadLink(url: url!, decode: decode)
                })
            })
        }, failedAction: { (err) in
            print(err)
        }, isAutomaticallyPass: false);
        
        let main1Page = PCWebBullet(method: .get, headFields: ["Accept-Language":"zh-cn",
                                                               "Upgrade-Insecure-Requests":"1",
                                                               "Accept-Encoding":"gzip, deflate",
                                                               "Accept":fullAccept,
                                                               "User-Agent":userAgent], formData: [:], url: file.url, injectJavaScript: [])
        let main2Page = PCWebBullet(method: .get, headFields: ["Accept-Language":"zh-cn",
                                                               "Upgrade-Insecure-Requests":"1",
                                                               "Accept-Encoding":"gzip, deflate",
                                                               "Accept":fullAccept,
                                                               "User-Agent":userAgent,
                                                               "Referer":file.url.absoluteString], formData: [:], url: down2.url, injectJavaScript: [])
        let main3Page = PCWebBullet(method: .get, headFields: ["Accept-Language":"zh-cn",
                                                               "Upgrade-Insecure-Requests":"1",
                                                               "Accept-Encoding":"gzip, deflate",
                                                               "Accept":fullAccept,
                                                               "User-Agent":userAgent,
                                                               "Referer":down2.url.absoluteString], formData: [:], url: down.url, injectJavaScript: [main3Unit])
        watting += [main1Page, main2Page, main3Page]
        seat?.webView.load(watting[0].request)
    }
    
    func loadDownloadLink(url: URL, decode: String) {
        var down = PageURL.down
        down.fileID = fileID
        
        let unit = InjectUnit(script: "document.body.innerHTML;", successAction: { (data) in
            guard let body = data as? String else {
                print("***** Not string!")
                return
            }
            print(body)
        }, failedAction: { (err) in
            print(err)
        }, isAutomaticallyPass: false);
        
        let header = ["Connection": "keep-alive",
                      "Referer": down.url.absoluteString,
                      "Accept-Language": "zh-cn",
                      "Origin": "http://www.yousuwp.com",
                      "Upgrade-Insecure-Requests": "1",
                      "Content-Type": "application/x-www-form-urlencoded",
                      "Accept-Encoding": "gzip, deflate",
                      "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                      "User-Agent": userAgent,
                      "Host": url.portHost]
        
        let download = PCWebBullet(method: .get, headFields: header, formData: [:], url: url, injectJavaScript: [unit])
        watting.append(download)
        seat?.webView.load(watting[0].request)
        
//        var down = PageURL.down
//        down.fileID = fileID
//        let header = ["Connection": "keep-alive",
//                      "Referer": down.url.absoluteString,
//                      "Accept-Language": "zh-cn",
//                      "Origin": "http://www.yousuwp.com",
//                      "Upgrade-Insecure-Requests": "1",
//                      "Content-Type": "application/x-www-form-urlencoded",
//                      "Accept-Encoding": "gzip, deflate",
//                      "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
//                      "User-Agent": userAgent]
//        let post = "dcode=\(decode)"
//        var request = PCDownloadRequest(headFields: header, url: url, method: .post, body: post.data(using: .utf8)!)
//        request.isFileDownloadTask = false
//        request.downloadStateUpdate = nil
//        request.downloadFinished = { (tk) in
//            guard let dat = tk.pack.revData, let str = String(data: dat, encoding: .utf8) else {
//                print("worong data!")
//                return
//            }
//            print("+++++ Parser string success: \(str)")
//
//            do {
//                let regx = try NSRegularExpression(pattern: "http://\\w+\\.\\w+.\\w+[:\\w]+/\\w+\\.\\w+\\?[^\"]+", options: NSRegularExpression.Options.caseInsensitive)
//                if let result = regx.firstMatch(in: str, options: .reportProgress, range: NSRange(location: 0, length: (str as NSString).length)) {
//                    let link = (str as NSString).substring(with: result.range)
//                    print("++++++ find download link: \(link)")
//
//                    guard let urlx = URL(string: link) else {
//                        print("+++++ Link not url string: \(link)")
//                        self.downloadFinished()
//                        return
//                    }
//
//                    var fileDownloadRequest = PCDownloadRequest(headFields: ["Referer":request.url.absoluteString,
//                                                                             "Accept-Language":"zh-cn",
//                                                                             "Upgrade-Insecure-Requests":"1",
//                                                                             "Accept-Encoding":"gzip, deflate",
//                                                                             "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
//                                                                             "User-Agent":userAgent], url: urlx, method: .get, body: nil)
//                    fileDownloadRequest.downloadStateUpdate = nil
//                    fileDownloadRequest.downloadFinished = { pack in
//                        print(pack.pack.revData?.debugDescription ?? "\n%%%%%%%%%%%%%%%%%%%%%% No data! %%%%%%%%%%%%%%%%%%%%%%")
//                        if let data = pack.pack.revData, let str = String(data: data, encoding: .utf8) {
//                            print("%%%%%%%%%%%%%%%%%%%%%% data %%%%%%%%%%%%%%%%%%%%%%\n")
//                            print(str)
//                            print("%%%%%%%%%%%%%%%%%%%%%% data %%%%%%%%%%%%%%%%%%%%%%")
//                        }
//
//                        defer {
//                            self.downloadFinished()
//                        }
//
//                        FileManager.default.save(pack: pack)
//                    }
//                    fileDownloadRequest.riffle = self
//                    PCDownloadManager.share.add(request: fileDownloadRequest)
//                }   else    {
//                    self.downloadFinished()
//                }
//            }   catch   {
//                print("*********** \(error)")
//                self.downloadFinished()
//            }
//        }
//        PCDownloadManager.share.add(request: request)
    }
}

extension URL {
    var portHost: String {
        do {
            let regx = try NSRegularExpression(pattern: "\\w+\\.\\w+.\\w+[:\\d]+", options: NSRegularExpression.Options.caseInsensitive)
            if let result = regx.firstMatch(in: self.absoluteString, options: .reportProgress, range: NSRange(location: 0, length: (self.absoluteString as NSString).length)) {
                let link = (self.absoluteString as NSString).substring(with: result.range)
                return link
            }
            return ""
        } catch {
            print(error)
            return ""
        }
    }
}
