//
//  Feemoo.swift
//  CCCHOOO
//
//  Created by virus1993 on 2018/2/16.
//  Copyright © 2018年 ascp. All rights reserved.
//

import AppKit

/// 飞猫网盘，只需要传入首页链接和输入正确验证码即可下载
public class Feemoo: WebRiffle {
    /// 文件id，从页面获取，有的页面链接不包含文件id
    var fileid = ""
    /// 文件名，从页面获取
    var fileName = ""
    /// 验证码页面url地址
    var feemooRefer = ""
    override var scriptName : String {
        return "feemoo"
    }
    
    public init(urlString: String) {
        super.init()
        mainURL = URL(string: urlString)        
    }
    
    override public func begin() {
        loadFeemooSequenceBullet()
    }
    
    /// 启动序列
    private func loadFeemooSequenceBullet() {
        guard let url = mainURL else {
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
            
            
            if let fileid = dic["fileid"], let href = dic["href"], let cookie = dic["cookie"] {
                print("fileid: \(fileid)")
                print("href: \(href)")
                print("cookie: \(cookie)")
                self.fileid = fileid
                self.feemooRefer = href
            }
            
        }, failedAction: nil, isAutomaticallyPass: true)
        let mainPage = WebBullet(method: .get, headFields: [:], formData: [:], url: url, injectJavaScript: [mainJSUnit])
        let secondPage = reloadCodeImageMaker(url: url)
        
        bullets = [mainPage, secondPage]
        bulletsIterator = bullets.makeIterator()
        currentResult = bulletsIterator?.next()
        webView.load(currentResult!.request)
    }
    
    /// 只获取验证码页面
    ///
    /// - Parameter url: 验证码页面url
    func reloadCodeImage(url: URL) {
        let secondPage = reloadCodeImageMaker(url: url)
        
        bullets = [secondPage]
        bulletsIterator = bullets.makeIterator()
        currentResult = bulletsIterator?.next()
        webView.load(currentResult!.request)
    }
    
    /// 验证码页面配置
    ///
    /// - Parameter url: 验证码页面url
    /// - Returns: WebBullet实例，主要用于从新获取验证码
    func reloadCodeImageMaker(url: URL) -> WebBullet {
        let secondJSUnit = InjectUnit(script: "\(functionScript) getCodeImageAndCodeEncry();", successAction: {
            dat in
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1, execute: {
                self.webView.evaluateJavaScript("function callFetchImage() {return { \"img\": getBase64Image(document.getElementById('verityImgtag')), \"codeencry\": codeencry} } callFetchImage();", completionHandler: { (datx, err) in
                    guard let dic = datx as? [String:String],
                        let img = dic["img"],
                        let _ = dic["codeencry"],
                        let base64 = Data(base64Encoded: img),
                        let image = NSImage(data: base64) else {
                            print("wrong data!")
                            return
                    }
                    AIBot.recognize(codeImage: image, completion: { (labels) in
                        let code = labels.first + labels.second + labels.third + labels.four
                        print("************ found code: \(code)")
                        self.loadFeemooDownloadLink(code: code)
                    })
                })
            })
        }, failedAction: nil, isAutomaticallyPass: false)
        let secondPage = WebBullet(method: .get, headFields: [:], formData: [:], url: url, injectJavaScript: [secondJSUnit])
        return secondPage
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
                return
            }
            print("+++++ Parser string success: \(str)")
            
            guard let url = URL(string: str) else {
                print("+++++ Link not url string: \(str)")
                if let url = self.mainURL, let _ = str.range(of: " failed") {
                    self.verifyCodeParserErrorCount += 1
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2, execute: {
                        self.reloadCodeImage(url: url)
                    })
                }   else    {
                    self.downloadFinished()
                }
                return
            }
            
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
                
                defer {
                    self.downloadFinished()
                }
                
                if let data = pack.revData, let str = String(data: data, encoding: .utf8) {
                    print("%%%%%%%%%%%%%%%%%%%%%% data %%%%%%%%%%%%%%%%%%%%%%\n")
                    print(str)
                    print("%%%%%%%%%%%%%%%%%%%%%% data %%%%%%%%%%%%%%%%%%%%%%")
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
            }, headFields: ["Referer":self.feemooRefer,
                            "Accept-Language":"zh-cn",
                            "Upgrade-Insecure-Requests":"1",
                            "Accept-Encoding":"gzip, deflate",
                            "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                            "User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_2) AppleWebKit/604.4.7 (KHTML, like Gecko) Version/11.0.2 Safari/604.4.7"], url: url, method: .get, body: nil))
        }, failedAction: { (e) in
            print(e)
        }, isAutomaticallyPass: true)
        self.currentResult?.injectJavaScript = [imageCodeUnit, fetchLink]
        execNextCommand()
    }
}
