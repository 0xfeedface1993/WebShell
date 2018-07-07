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
public class Pan666 : PCWebRiffle {
    override public var scriptName: String {
        return "666pan"
    }
    
    /// 文件名，从页面获取
    var fileName = ""
    /// 文件ID
    var fileNumber = ""
    /// 首页，因为会出现重定向的问题，先写死，后期解决这个问题
    var pan6661URL : URL {
        return URL(string: "http://www.678pan.org/file-\(fileNumber).html")!
    }
    /// 中转页面，重定向问题
    var pan6662URL : URL {
        return URL(string: "http://www.678pan.org/down2-\(fileNumber).html")!
    }
    /// 验证码输入页面，重定向问题
    var pan6663URL : URL {
        return URL(string: "http://www.678pan.org/down-\(fileNumber).html")!
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
            self.host = .pan666
        }
    }
    
    override public func begin() {
        loadWebView()
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
        
        let main1Page = PCWebBullet(method: .get, headFields: ["Accept-Language":"zh-cn",
                                                             "Upgrade-Insecure-Requests":"1",
                                                             "Accept-Encoding":"gzip, deflate",
                                                             "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                                             "User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_3) AppleWebKit/604.5.6 (KHTML, like Gecko) Version/11.0.3 Safari/604.5.6"], formData: [:], url: pan6661URL, injectJavaScript: [main1Unit])
        let main2Page = PCWebBullet(method: .get, headFields: ["Accept-Language":"zh-cn",
                                                             "Upgrade-Insecure-Requests":"1",
                                                             "Accept-Encoding":"gzip, deflate",
                                                             "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                                             "User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_3) AppleWebKit/604.5.6 (KHTML, like Gecko) Version/11.0.3 Safari/604.5.6",
                                                             "Referer":pan6661URL.absoluteString], formData: [:], url: pan6662URL, injectJavaScript: [])
        watting += [main1Page, main2Page]
        reload666PanImagePage()
    }
    
    var verifyCode = "abcd"
    
    /// 获取验证码并验证
    func reload666PanImagePage() {
        func imagePaserUnitMaker() -> [InjectUnit] {
            let delayTime = 0.5

            let uploadCodeUnit = InjectUnit(script: "\(functionScript) check_code('\(verifyCode)');", successAction: { (dat) in
                DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + delayTime, execute: {
                    self.execNextCommand()
                })
            }, failedAction: { _ in
                self.downloadFinished()
            }, isAutomaticallyPass: false)
            
            let loadDownloadAddressUnit = InjectUnit(script: "getMiddleLink();", successAction: { (dat) in
                guard let link = dat as? String, let url = URL(string: link) else {
                    print("worong data!")
                    self.downloadFinished()
                    return
                }
                
                self.readDownloadLink(url: url)
            }, failedAction: { _ in
                self.downloadFinished()
            }, isAutomaticallyPass: true)
            
            return [uploadCodeUnit, loadDownloadAddressUnit]
        }
        
        let units = imagePaserUnitMaker()
        
        let main3Page = PCWebBullet(method: .get, headFields: ["Accept-Language":"zh-cn",
                                                             "Upgrade-Insecure-Requests":"1",
                                                             "Accept-Encoding":"gzip, deflate",
                                                             "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                                             "User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_3) AppleWebKit/604.5.6 (KHTML, like Gecko) Version/11.0.3 Safari/604.5.6",
                                                             "Referer":pan6662URL.absoluteString], formData: [:], url: pan6663URL, injectJavaScript: units)
        watting += [main3Page]
        
        seat?.webView.load(watting[0].request)
    }
    
    /// 读取下载地址并开始下载
    ///
    /// - Parameter url: 下载地址（含sign参数）
    func readDownloadLink(url: URL) {
        var fileDownloadRequest = PCDownloadRequest(headFields: ["Host":url.host!,
                                                                 "Connection":"keep-alive",
                                                                 "Upgrade-Insecure-Requests":"1",
                                                                 "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                                                 "User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/11.1.1 Safari/605.1.15",
                                                                 "Referer":pan6663URL.absoluteString,
                                                                 "Accept-Language":"zh-cn",
                                                                 "Accept-Encoding":"gzip, deflate"], url: url, method: .get, body: nil, uuid: uuid)
        fileDownloadRequest.downloadStateUpdate = nil
        fileDownloadRequest.downloadFinished = { pack in
            print(pack.pack.revData?.debugDescription ?? "\n%%%%%%%%%%%%%%%%%%%%%% No data! %%%%%%%%%%%%%%%%%%%%%%")
            if let data = pack.pack.revData, let str = String(data: data, encoding: .utf8) {
                print("%%%%%%%%%%%%%%%%%%%%%% data %%%%%%%%%%%%%%%%%%%%%%\n")
                print(str)
                print("%%%%%%%%%%%%%%%%%%%%%% data %%%%%%%%%%%%%%%%%%%%%%")
            }
            
            defer {
                self.downloadFinished()
            }
            
            FileManager.default.save(pack: pack)
        }
        fileDownloadRequest.riffle = self
        PCDownloadManager.share.add(request: fileDownloadRequest)
    }
}
