//
//  Ccchooo.swift
//  CCCHOOO
//
//  Created by virus1993 on 2018/2/24.
//  Copyright © 2018年 ascp. All rights reserved.
//

import Cocoa

/// 彩虹盘
public class Ccchooo: WebRiffle {
    /// 文件名，从页面获取
    var fileName = ""
    /// 文件ID
    var fileNumber = ""
    /// 下载列表绑定的数据，针对于使用视图绑定的情况，如果是其他情况请声明其他变量并进行控制
    public weak var downloadStateController : NSArrayController?
    override var scriptName : String {
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
            print("fileNumber: \(fileNumber)")
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
        let mainPage = WebBullet(method: .get,
                                 headFields: [:],
                                 formData: [:],
                                 url: URL(string: "http://www.ccchoo.com/down-\(fileNumber).html")!,
                                 injectJavaScript: [mainJSUnit])
        let main2Page = WebBullet(method: .get, headFields: ["Referer":"http://www.ccchoo.com/file-\(fileNumber).html",
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
            }
            
//            if let base64 = dic["image"], let data = Data(base64Encoded: base64), let img = NSImage(data: data) {
//                self.code.image = img
//            }
        }, failedAction: nil, isAutomaticallyPass: true)
        let main3Page = WebBullet(method: .get, headFields: ["Referer":"http://www.ccchoo.com/down2-\(fileNumber).html",
            "Accept-Language":"zh-cn",
            "Upgrade-Insecure-Requests":"1",
            "Accept-Encoding":"gzip, deflate",
            "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_2) AppleWebKit/604.4.7 (KHTML, like Gecko) Version/11.0.2 Safari/604.4.7"],
                                  formData: [:],
                                  url: URL(string: "http://www.ccchoo.com/down-\(fileNumber).html")!,
                                  injectJavaScript: [main3JSUnit])
        bullets = [mainPage, main2Page, main3Page]
        bulletsIterator = bullets.makeIterator()
        currentResult = bulletsIterator?.next()
        webView.load(currentResult!.request)
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
            DownloadManager.share.add(request: DownloadRequest(label: label, fileName: self.fileName, downloadStateUpdate: { pack in
                guard let controller = self.downloadStateController else {   return  }
                var items = controller.content as! [DownloadInfo]
                if let index = items.index(where: { $0.uuid == label }) {
                    items[index].progress = "\(pack.progress * 100)%"
                    items[index].totalBytes = "\(pack.totalBytes / 1024 / 1024)M"
                    items[index].site = pack.request.url.host!
                    controller.content = items
                    return
                }
                let info = DownloadInfo()
                info.uuid = label
                info.name = self.fileName
                info.progress = "\(pack.progress * 100)%"
                info.totalBytes = "\(pack.totalBytes / 1024 / 1024)M"
                info.site = pack.request.url.host!
                items.append(info)
                controller.content = items
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
                if let urlString = NSSearchPathForDirectoriesInDomains(.downloadsDirectory, .userDomainMask, true).first {
                    let url = URL(fileURLWithPath: urlString).appendingPathComponent(pack.request.fileName)
                    do {
                        try pack.revData?.write(to: url)
                        print(">>>>>> file saved! <<<<<<")
                    } catch {
                        print(error)
                    }
                }
            }, headFields: ["Referer":"http://www.ccchoo.com/down-\(self.fileNumber).html",
                "Accept-Language":"zh-cn",
                "Upgrade-Insecure-Requests":"1",
                "Accept-Encoding":"gzip, deflate",
                "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                "User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_2) AppleWebKit/604.4.7 (KHTML, like Gecko) Version/11.0.2 Safari/604.4.7"], url: url, method: .post, body: nil))
        }, failedAction: nil, isAutomaticallyPass: true)
        
        let codeUpload = WebBullet(method: .post, headFields: ["Referer":"http://www.ccchoo.com/down-\(fileNumber).html",
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
        bullets = [codeUpload]
        bulletsIterator = bullets.makeIterator()
        currentResult = bulletsIterator?.next()
        webView.load(currentResult!.request)
    }
}
