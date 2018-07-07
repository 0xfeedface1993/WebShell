//
//  Feemoo.swift
//  CCCHOOO
//
//  Created by virus1993 on 2018/2/16.
//  Copyright © 2018年 ascp. All rights reserved.
//

#if os(macOS)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

/// 飞猫网盘，只需要传入首页链接和输入正确验证码即可下载
public class Feemoo: PCWebRiffle {
    /// 文件id，从页面获取，有的页面链接不包含文件id
    var fileid = ""
    /// 文件名，从页面获取
    var fileName = ""
    /// 验证码页面url地址
    var feemooRefer = ""
    override public var scriptName : String {
        return "feemoo"
    }
    
    public init(urlString: String) {
        super.init()
        if let url = URL(string: urlString) {
            host = siteType(url: url)
            mainURL = URL(string: "http://www.feemoo.com" + url.path)
        }
    }
    
    override public func begin() {
        loadWebView()
        startSequence()
    }
    
    /// 抓取下载链接，并开始下载
    ///
    /// - Parameter code: 验证码文本
    private func loadFeemooDownloadLink(code: String) {
        let imageCodeUnit = InjectUnit(script: "com_down('\(fileid)', '\(code)', null);", successAction: { _ in
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2, execute: {
                self.execNextCommand()
            })
        }, failedAction: { (err) in
            print("download link fetch js error: " + err.localizedDescription)
            self.execNextCommand()
        }, isAutomaticallyPass: false)
        
        let fetchLink = InjectUnit(script: "fetchDownloadLink();", successAction: { daty in
            guard let str = daty as? String else {
                print("ooops! not string!")
                self.downloadFinished()
                return
            }
            print("+++++ Parser string success: \(str)")
            
            guard let url = URL(string: str) else {
                print("+++++ Link not url string: \(str)")
                if let _ = str.range(of: " failed") {
                    self.verifyCodeParserErrorCount += 1
                    if self.verifyCodeParserErrorCount >= 50 {
                        self.downloadFinished()
                        return
                    }
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5, execute: {
                        self.watting[0].injectJavaScript = self.imageInjectUnitMaker()
                        self.execNextCommand()
                    })
                }   else    {
                    self.downloadFinished()
                }
                return
            }
            
            self.redirectDownload(url: url)
        }, failedAction: { (e) in
            print(e)
        }, isAutomaticallyPass: false)
        
        watting[0].injectJavaScript = [imageCodeUnit, fetchLink]
        execNextCommand()
    }
    
    
    // 测试下载
    func startSequence() {
        guard let url = mainURL else {
            print("**************** File URL NOT Found ****************")
            return
        }
        
        let mainJSUnit = InjectUnit(script: "\(functionScript) getSecondPageLinkAndFileName();", successAction: {
            dat in
            guard let dic = dat as? [String:String] else {
                print("wrong data!")
                return
            }
            
            self.fileName = dic["fileName"] ?? (UUID().uuidString + ".feemoo")
            print("file name: \(self.fileName)")
            
            
            if let fileid = dic["fileid"], let href = dic["href"] {
                print("fileid: \(fileid)")
                print("href: \(href)")
                self.fileid = fileid
                self.feemooRefer = href
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1, execute: {
                    secondPageLoad()
                })
            }   else    {
                self.downloadFinished()
            }
        }, failedAction: { _ in self.downloadFinished() }, isAutomaticallyPass: false)
        
        let mainPage = PCWebBullet(method: .get, headFields: ["Connection": "keep-alive",
                                                              "Accept-Language": "zh-cn",
                                                              "Upgrade-Insecure-Requests": "1",
                                                              "Accept-Encoding": "gzip, deflate",
                                                              "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                                              "User-Agent": userAgent,
                                                              "Host": url.host ?? ""], formData: [:], url: url, injectJavaScript: [mainJSUnit])
       
        
        func secondPageLoad() {
            let secondJSUnit = InjectUnit(script: "\(functionScript) getCodeImageAndCodeEncry();", successAction: { (dat) in
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1, execute: {
                    self.watting[0].injectJavaScript = self.imageInjectUnitMaker()
                    self.execNextCommand()
                })
            }, failedAction: { (err) in
                self.downloadFinished()
            }, isAutomaticallyPass: false)
            
            let secondPage = PCWebBullet(method: .get,
                                         headFields: ["Host":url.host ?? "",
                                                      "Upgrade-Insecure-Requests":"1",
                                                      "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                                      "User-Agent":userAgent,
                                                      "Referer":url.absoluteString,
                                                      "Accept-Language":"zh-cn",
                                                      "Accept-Encoding":"gzip, deflate",
                                                      "Connection":"keep-alive"],
                                         formData: [:],
                                         url: url,
                                         injectJavaScript: [secondJSUnit])
            watting = [secondPage]
            seat?.webView.load(watting[0].request)
        }
        
        watting = [mainPage]
        seat?.webView.load(watting[0].request)
    }
    
    func imageInjectUnitMaker() -> [InjectUnit] {
        let reloadUnit = InjectUnit(script: "\(functionScript) getimgcoded();", successAction: { (dat) in
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1, execute: {
                self.execNextCommand()
            })
        }, failedAction: { (err) in
            self.downloadFinished()
        }, isAutomaticallyPass: false)
        
        let fetchUnit = InjectUnit(script: "getImageString();", successAction: { (dat) in
            guard let str = dat as? String, let base64 = Data(base64Encoded: str) else {
                self.downloadFinished()
                return
            }
            
            let image = ImageMaker(data: base64)
            AIBot.recognize(codeImage: image, completion: { (labels) in
                let code = labels.first + labels.second + labels.third + labels.four
                print("************ found code: \(code)")
                self.loadFeemooDownloadLink(code: code)
            })
            
        }, failedAction: { (err) in
            self.downloadFinished()
        }, isAutomaticallyPass: false)
        
        return [reloadUnit, fetchUnit]
    }
    
    /// 通过中转文件地址获取重定向文件地址
    ///
    /// - Parameter url: 中转文件地址
    func redirectDownload(url: URL) {
        var fileDownloadRequest = PCDownloadRequest(headFields: ["Referer":self.feemooRefer,
                                                                 "Accept-Language":"zh-cn",
                                                                 "Upgrade-Insecure-Requests":"1",
                                                                 "Accept-Encoding":"gzip, deflate",
                                                                 "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                                                 "User-Agent":userAgent], url: url, method: .get, body: nil, uuid: UUID())
        self.feemooRefer = url.absoluteString
        fileDownloadRequest.downloadStateUpdate = nil
        fileDownloadRequest.downloadFinished = { pack in
            print(pack.pack.revData?.debugDescription ?? "%%%%%%%%%%%%%%%%%%%%%% No data! %%%%%%%%%%%%%%%%%%%%%%")
            
            if let response = pack.task.response as? HTTPURLResponse, let location = response.allHeaderFields["Location"] as? String, let fileURL = URL(string: location) {
                self.downloadFile(url: fileURL)
            }   else    {
                self.downloadFinished()
            }
        }
        fileDownloadRequest.riffle = self
        fileDownloadRequest.isFileDownloadTask = false
        PCDownloadManager.share.add(request: fileDownloadRequest)
    }
    
    
    /// 下载文件
    ///
    /// - Parameter url: 文件实际下载路径
    func downloadFile(url: URL) {
        var fileDownloadRequest = PCDownloadRequest(headFields: ["Referer":self.feemooRefer,
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
