//
//  Feemoo.swift
//  CCCHOOO
//
//  Created by virus1993 on 2018/2/16.
//  Copyright © 2018年 ascp. All rights reserved.
//

import AppKit
// http://www.feemoo.com/s/v2j0z15j
extension ViewController {
    func loadFeemooSequenceBullet() {
        scriptName = "feemoo"
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
                self.feemooCookie = cookie
                self.fileid = fileid
                self.feemooRefer = href
                
            }
            
        }, failedAction: nil, isAutomaticallyPass: true)
        let urlString = "http://www.feemoo.com/s/v2j0z15j"
        let mainPage = WebBullet(method: .get, headFields: [:], formData: [:], url: URL(string: urlString)!, injectJavaScript: [mainJSUnit])
        
        let secondJSUnit = InjectUnit(script: "\(functionScript) getCodeImageAndCodeEncry();", successAction: {
            dat in
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1, execute: {
                self.webview.evaluateJavaScript("function callFetchImage() {return { \"img\": getBase64Image(document.getElementById('verityImgtag')), \"codeencry\": codeencry} } callFetchImage();", completionHandler: { (datx, err) in
                    guard let dic = datx as? [String:String] else {
                        print("wrong data!")
                        return
                    }
                    if let img = dic["img"], let _ = dic["codeencry"] {
                        if let base64 = Data(base64Encoded: img) {
                            DispatchQueue.main.async {
                                self.code.image = NSImage(data: base64)
                            }
                        }
                    }
                })
            })
        }, failedAction: nil, isAutomaticallyPass: false)
        let secondPage = WebBullet(method: .get, headFields: [:], formData: [:], url: URL(string: urlString)!, injectJavaScript: [secondJSUnit])

        bullets = [mainPage, secondPage]
        bulletsIterator = bullets.makeIterator()
        currentResult = bulletsIterator?.next()
    }
    
    func loadFeemooDownloadLink(code: String) {
        let imageCodeUnit = InjectUnit(script: "com_down('\(fileid)', '\(code)', null);", successAction: { _ in
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2, execute: {
                self.execNextCommand()
            })
        }, failedAction: { (err) in
            print(err.localizedDescription)
            self.execNextCommand()
        }, isAutomaticallyPass: false)
        
        let fetchLink = InjectUnit(script: "fetchDownloadLink();", successAction: { daty in
            guard let str = daty as? String else {
                print("ooops! not string!")
                return
            }
            print(str)
            if let url = URL(string: str) {
                let label = UUID().uuidString
                DownloadManager.share.add(request: DownloadRequest(label: label, fileName: self.fileName, downloadStateUpdate: { pack in
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
                    info.name = self.fileName
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
                let pasteBoard = NSPasteboard.general
                pasteBoard.clearContents()
                pasteBoard.writeObjects([str] as [NSPasteboardWriting])
                print(">>>>>>>>> copy url done ! <<<<<<<<<")
            }
        }, failedAction: { (e) in
            print(e)
        }, isAutomaticallyPass: true)
        self.currentResult?.injectJavaScript = [imageCodeUnit, fetchLink]
        execNextCommand()
    }
}

struct FeemooDownloadInfo : Decodable {
    var status : Bool
    var str : String
}

struct FeemooImageCodeInfo : Decodable {
    var code : String
    var base : String
    func base654ImageString() -> String {
        return String(base.split(separator: ",").last ?? "")
    }
}

class Feemoo: WebRiffle {
    var fileid = ""
    var fileName = ""
    var feemooRefer = ""
    var mainURL : URL?
    override var scriptName : String {
        return "feemoo"
    }
    weak var downloadStateController : NSArrayController?
    
    init(urlString: String) {
        super.init()
        mainURL = URL(string: urlString)
    }
    
    override func begin() {
        loadFeemooSequenceBullet()
    }
    
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
        
        /// 只获取验证码页面
        func reloadCodeImage(){
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
                        DispatchQueue.main.async {
                            if let promotViewController = NSApp.windows.first(where: { (w) -> Bool in
                                guard w.contentViewController?.isKind(of: VerifyCodeViewController.self) ?? false else {
                                    return false
                                }
                                let vc = w.contentViewController as! VerifyCodeViewController
                                return vc.presentingRiffle == self
                            })?.contentViewController as? VerifyCodeViewController {
                                promotViewController.codeView.imageView.image = image
                            }   else    {
                                self.show(verifyCode: image, confirm: { (code) in
                                    self.loadFeemooDownloadLink(code: code)
                                }, reloadWay: { (imageView) in
                                    reloadCodeImage()
                                }, withRiffle: self)
                            }
                        }
                    })
                })
            }, failedAction: nil, isAutomaticallyPass: false)
            let secondPage = WebBullet(method: .get, headFields: [:], formData: [:], url: url, injectJavaScript: [secondJSUnit])
            
            bullets = [secondPage]
            bulletsIterator = bullets.makeIterator()
            currentResult = bulletsIterator?.next()
            webView.load(currentResult!.request)
        }
        
        let secondJSUnit = InjectUnit(script: "\(functionScript) getCodeImageAndCodeEncry();", successAction: {
            dat in
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1, execute: {
                self.webView.evaluateJavaScript("function callFetchImage() {return { \"img\": getBase64Image(document.getElementById('verityImgtag')), \"codeencry\": codeencry} } callFetchImage();", completionHandler: { (datx, err) in
                    guard let dic = datx as? [String:String] else {
                        print("wrong data!")
                        return
                    }
                    if let img = dic["img"], let _ = dic["codeencry"] {
                        if let base64 = Data(base64Encoded: img), let image = NSImage(data: base64) {
                            DispatchQueue.main.async {
                                self.show(verifyCode: image, confirm: { (code) in
                                    self.loadFeemooDownloadLink(code: code)
                                }, reloadWay: { (imageView) in
                                    reloadCodeImage()
                                }, withRiffle: self)
                            }
                        }
                    }
                })
            })
        }, failedAction: nil, isAutomaticallyPass: false)
        let secondPage = WebBullet(method: .get, headFields: [:], formData: [:], url: url, injectJavaScript: [secondJSUnit])
        
        bullets = [mainPage, secondPage]
        bulletsIterator = bullets.makeIterator()
        currentResult = bulletsIterator?.next()
        webView.load(currentResult!.request)
    }
    
    private func loadFeemooDownloadLink(code: String) {
        let imageCodeUnit = InjectUnit(script: "com_down('\(fileid)', '\(code)', null);", successAction: { _ in
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2, execute: {
                self.execNextCommand()
            })
        }, failedAction: { (err) in
            print(err.localizedDescription)
            self.execNextCommand()
        }, isAutomaticallyPass: false)
        
        let fetchLink = InjectUnit(script: "fetchDownloadLink();", successAction: { daty in
            guard let str = daty as? String else {
                print("ooops! not string!")
                return
            }
            print(str)
            if let url = URL(string: str) {
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
                    
                    self.downloadFinished(task: pack)
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
            }
        }, failedAction: { (e) in
            print(e)
        }, isAutomaticallyPass: true)
        self.currentResult?.injectJavaScript = [imageCodeUnit, fetchLink]
        execNextCommand()
    }
}
