//
//  Ccchooo.swift
//  CCCHOOO
//
//  Created by virus1993 on 2018/2/24.
//  Copyright © 2018年 ascp. All rights reserved.
//

#if TARGET_OS_MAC
    import Cocoa
#elseif TARGET_OS_IPHONE
    import UIKit
#endif

/// 彩虹盘
public class Ccchooo: PCWebRiffle {
    /// 文件名，从页面获取
    var fileName = ""
    /// 文件ID
    var fileNumber = ""
    override public var scriptName : String {
        return "ccchooo"
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
            print("-------- fileNumber: \(fileNumber)")
            host = .cchooo
        }
    }
    
    override public func begin() {
        loadCCCHOOOSequenceBullet()
    }
    
    /// 启动序列
    func loadCCCHOOOSequenceBullet() {
        let mainJSUnit = InjectUnit(script: "\(functionScript) getFileName();", successAction: {
            dat in
            guard let name = dat as? String else {
                print("no name!")
                self.fileName = UUID().uuidString + ".ccchooo"
                return
            }
            
            self.fileName = name
            print("file name: \(name)")
        }, failedAction: nil, isAutomaticallyPass: true)
        let mainPage = PCWebBullet(method: .get,
                                 headFields: [:],
                                 formData: [:],
                                 url: URL(string: "http://www.ccchoo.com/down-\(fileNumber).html")!,
                                 injectJavaScript: [mainJSUnit])
        let main2Page = PCWebBullet(method: .get, headFields: ["Referer":"http://www.ccchoo.com/file-\(fileNumber).html",
            "Accept-Language":"zh-cn",
            "Upgrade-Insecure-Requests":"1",
            "Accept-Encoding":"gzip, deflate",
            "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_2) AppleWebKit/604.4.7 (KHTML, like Gecko) Version/11.0.2 Safari/604.4.7"],
                                  formData: [:],
                                  url: URL(string: "http://www.ccchoo.com/down2-\(fileNumber).html")!,
                                  injectJavaScript: [])
        let main3JSUnit = InjectUnit(script: "\(functionScript) getImageAndLink();", successAction: {
            dat in
            guard let dic = dat as? [String:String] else {
                print("no data!")
                return
            }
            
            if let url = URL(string: dic["link"] ?? "") {
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1, execute: {
                    self.loadCCCHOOODownloadLink(code: "1234", downloadLink: url)
                })
                
                print("link: \(url.absoluteString)")
            }   else {
                self.downloadFinished()
            }
        }, failedAction: nil, isAutomaticallyPass: true)
        let main3Page = PCWebBullet(method: .get, headFields: ["Referer":"http://www.ccchoo.com/down2-\(fileNumber).html",
            "Accept-Language":"zh-cn",
            "Upgrade-Insecure-Requests":"1",
            "Accept-Encoding":"gzip, deflate",
            "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_2) AppleWebKit/604.4.7 (KHTML, like Gecko) Version/11.0.2 Safari/604.4.7"],
                                  formData: [:],
                                  url: URL(string: "http://www.ccchoo.com/down-\(fileNumber).html")!,
                                  injectJavaScript: [main3JSUnit])
        watting = [mainPage, main3Page]
        
        if Thread.isMainThread {
            webView.load(watting[0].request)
        }   else    {
            DispatchQueue.main.async {
                self.webView.load(self.watting[0].request)
            }
        }
    }
    
    /// 下载文件
    ///
    /// - Parameters:
    ///   - code: 验证码，目前可以是错误的
    ///   - downloadLink: 下载链接，调用验证码服务再下载
    func loadCCCHOOODownloadLink(code: String, downloadLink: URL) {
        let codeUploadUnit = InjectUnit(script: "var code=0;", successAction: {
            dat in
            let url = downloadLink
            let label = UUID().uuidString
            var fileDownloadRequest = PCDownloadRequest(headFields: ["Referer":"http://www.ccchoo.com/down-\(self.fileNumber).html",
                "Accept-Language":"zh-cn",
                "Upgrade-Insecure-Requests":"1",
                "Accept-Encoding":"gzip, deflate",
                "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                "User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_2) AppleWebKit/604.4.7 (KHTML, like Gecko) Version/11.0.2 Safari/604.4.7"], url: url, method: .post, body: nil)
            fileDownloadRequest.riffle = self
            fileDownloadRequest.downloadStateUpdate = nil
            fileDownloadRequest.downloadFinished = { pack in
                defer {
                    self.downloadFinished()
                }
                
                if let e = pack.pack.error {
                    print("************ \(e)")
                    return
                }
                
                print(pack.pack.revData?.debugDescription ?? "%%%%%%%%%%%%%%%%%%%%%% No data! %%%%%%%%%%%%%%%%%%%%%%")
                if let data = pack.pack.revData, let str = String(data: data, encoding: .utf8) {
                    print("%%%%%%%%%%%%%%%%%%%%%% data %%%%%%%%%%%%%%%%%%%%%%\n")
                    print(str)
                    print("%%%%%%%%%%%%%%%%%%%%%% data %%%%%%%%%%%%%%%%%%%%%%")
                }
                
                FileManager.default.save(pack: pack)
            }
            PCDownloadManager.share.add(request: fileDownloadRequest)
        }, failedAction: nil, isAutomaticallyPass: true)
        
        let codeUpload = PCWebBullet(method: .post, headFields: ["Referer":"http://www.ccchoo.com/down-\(fileNumber).html",
            "Origin":"http://www.ccchoo.com",
            "Accept-Language":"zh-cn",
            "Upgrade-Insecure-Requests":"1",
            "Accept-Encoding":"gzip, deflate",
            "Content-Type":"application/x-www-form-urlencoded; charset=UTF-8",
            "X-Requested-With":"XMLHttpRequest",
            "Accept":"*/*",
            "User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_2) AppleWebKit/604.4.7 (KHTML, like Gecko) Version/11.0.2 Safari/604.4.7"],
                                   formData: ["action":"check_code",
                                              "code":code,
                                              "vipd":"0"],
                                   url: URL(string: "http://www.ccchoo.com/ajax.php")!,
                                   injectJavaScript: [codeUploadUnit])
        watting.append(codeUpload)
        webView.load(watting[0].request)
    }
}
