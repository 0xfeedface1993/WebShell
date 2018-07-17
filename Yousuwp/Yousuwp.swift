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
        
        private static let host = "www.yousuwp.com"
        
        static let file = PageURL(rule: { id in return URL(string: "http://\(host)/file-\(id).html")! })
        static let down2 = PageURL(rule: { id in return URL(string: "http://\(host)/down2-\(id).html")! })
        static let down = PageURL(rule: { id in return URL(string: "http://\(host)/down-\(id).html")! })
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
        
        func imagePaserUnitMaker() -> [InjectUnit] {
            let delayTime = 0.5
            
            let uploadCodeUnit = InjectUnit(script: "\(functionScript) check_code('abcd');", successAction: { (dat) in
                DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + delayTime, execute: {
                    self.execNextCommand()
                })
            }, failedAction: { _ in
                self.downloadFinished()
            }, isAutomaticallyPass: false)
            
            let loadDownloadAddressUnit = InjectUnit(script: "getSubLinkAndDecode();", successAction: { (dat) in
                guard let items = dat as? [String : String] else {
                    print("****** Data not dictionary!")
                    self.downloadFinished()
                    return
                }
                
                guard let string = items["link"] else {
                    print("****** Link not found!")
                    self.downloadFinished()
                    return
                }
                
                guard let decode = items["decode"] else {
                    print("****** Decode not found!")
                    self.downloadFinished()
                    return
                }
                
                let url = URL(string: string)
                self.loadDownloadLink(url: url!, decode: decode)
            }, failedAction: { _ in
                self.downloadFinished()
            }, isAutomaticallyPass: true)
            
            return [uploadCodeUnit, loadDownloadAddressUnit]
        }
        
        let units3 = imagePaserUnitMaker()
        
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
                                                               "Referer":down2.url.absoluteString], formData: [:], url: down.url, injectJavaScript: units3)
        watting += [main1Page, main2Page, main3Page]
        seat?.webView.load(watting[0].request)
    }
    
    func loadDownloadLink(url: URL, decode: String) {
        var down = PageURL.down
        down.fileID = fileID
        let header = ["Host":url.portHost,
                      "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                      "Accept-Encoding":"gzip, deflate",
                      "Accept-Language":"zh-cn",
                      "Content-Type":"application/x-www-form-urlencoded",
                      "Origin":down.url.host!,
                      "User-Agent":userAgent,
                      "Connection":"keep-alive",
                      "Upgrade-Insecure-Requests":"1",
                      "Referer":down.url.absoluteString]
        let post = "dcode=\(decode)"
        var fileDownloadRequest = PCDownloadRequest(headFields: header, url: url, method: .post, body: post.data(using: .utf8)!, uuid: uuid)
        fileDownloadRequest.downloadStateUpdate = nil
        fileDownloadRequest.downloadFinished = { pack in
            print(pack.pack.revData?.debugDescription ?? "\n%%%%%%%%%%%%%%%%%%%%%% No data! %%%%%%%%%%%%%%%%%%%%%%")
            if let data = pack.pack.revData, let str = String(data: data, encoding: .utf8) {
                print("%%%%%%%%%%%%%%%%%%%%%% data %%%%%%%%%%%%%%%%%%%%%%\n")
                print(str)
                print("%%%%%%%%%%%%%%%%%%%%%% data %%%%%%%%%%%%%%%%%%%%%%")
            }
            
            if let response = pack.task.response as? HTTPURLResponse, response.statusCode == 302, let location = response.allHeaderFields["Location"] as? String, let fileURL = URL(string: location) {
                PCDownloadManager.share.removeFromBackgroundSession(originURL: url)
                self.downloadFile(url: fileURL, refer: url)
            }   else    {
                FileManager.default.save(pack: pack)
                self.downloadFinished()
            }
        }
        fileDownloadRequest.riffle = self
        PCDownloadManager.share.add(request: fileDownloadRequest)
    }
    
    /// 下载文件
    ///
    /// - Parameter url: 文件实际下载路径
    func downloadFile(url: URL, refer: URL) {
        var fileDownloadRequest = PCDownloadRequest(headFields: ["Referer":refer.absoluteString,
                                                                 "Accept-Language":"zh-cn",
                                                                 "Upgrade-Insecure-Requests":"1",
                                                                 "Accept-Encoding":"gzip, deflate",
                                                                 "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                                                 "User-Agent":userAgent], url: url, method: .get, body: nil, uuid: uuid)
        fileDownloadRequest.downloadStateUpdate = nil
        fileDownloadRequest.downloadFinished = { pack in
            print(pack.pack.revData?.debugDescription ?? "%%%%%%%%%%%%%%%%%%%%%% No data! %%%%%%%%%%%%%%%%%%%%%%")
            
            defer {
                self.downloadFinished()
            }
            
            if let data = pack.pack.revData, let str = String(data: data, encoding: .utf8) {
                print("%%%%%%%%%%%%%%%%%%%%%% data %%%%%%%%%%%%%%%%%%%%%%\n")
                print(str)
                print("%%%%%%%%%%%%%%%%%%%%%% data %%%%%%%%%%%%%%%%%%%%%%")
            }
            
            FileManager.default.save(pack: pack)
        }
        fileDownloadRequest.riffle = self
        PCDownloadManager.share.add(request: fileDownloadRequest)
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
