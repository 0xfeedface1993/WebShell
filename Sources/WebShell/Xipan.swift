//
//  Xipan.swift
//  WebShell_macOS
//
//  Created by virus1994 on 2019/5/26.
//  Copyright © 2019 ascp. All rights reserved.
//

#if os(macOS)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

public class Xipan : PCWebRiffle {
    override public var scriptName: String {
        return "666pan"
    }
    
    /// 文件名，从页面获取
    var fileName = ""
    /// 文件ID
    var fileNumber = ""
    /// 首页，因为会出现重定向的问题，先写死，后期解决这个问题
    var pan1URL : URL {
        return URL(string: "https://\(mainHost)/file-\(fileNumber).html")!
    }
    /// 中转页面，重定向问题
    var pan2URL : URL {
        return URL(string: "https://\(mainHost)/down2-\(fileNumber).html")!
    }
    /// 验证码输入页面，重定向问题
    var pan3URL : URL {
        return URL(string: "https://\(mainHost)/down-\(fileNumber).html")!
    }
    
    let mainHost = "www.xibupan.com"
    
    /// 初始化
    ///
    /// - Parameter urlString: 下载首页地址
    public required init(urlString: String) {
        super.init()
        mainURL = URL(string: urlString)
        /// 从地址中截取文件id
        let regx = try? NSRegularExpression(pattern: "\\d{5,}", options: NSRegularExpression.Options.caseInsensitive)
        let strNS = urlString as NSString
        if let result = regx?.firstMatch(in: urlString, options: NSRegularExpression.MatchingOptions.reportProgress, range: NSRange(location: 0, length: strNS.length)) {
            fileNumber = strNS.substring(with: result.range)
            print("fileNumber: \(fileNumber)")
            self.host = .xi
        }
    }
    
    override public func begin() {
        load666PanSequence()
    }
    
    /// 启动序列
    func load666PanSequence() {
        func loadPage(url: URL, header:[String:String] = [:], callback: ((PCDownloadTask) -> ())?) {
            var pageRequest = PCDownloadRequest(headFields: [:], url: url, method: HTTPMethod.get, body: nil, uuid: UUID(), friendName: self.friendName)
            pageRequest.downloadFinished = { task in
                callback?(task)
            }
            pageRequest.isFileDownloadTask = false
            pageRequest.riffle = self
            PCDownloadManager.share.add(request: pageRequest)
        }
        
        loadPage(url: pan1URL) { [weak self] _ in
            guard let pan2URL = self?.pan2URL, let pan1 = self?.pan1URL, let pan3 = self?.pan3URL else {
                self?.downloadFinished()
                return
            }
            loadPage(url: pan2URL, header: ["Accept-Language":"zh-cn",
                                                    "Upgrade-Insecure-Requests":"1",
                                                    "Accept-Encoding":"gzip, deflate",
                                                    "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                                    "User-Agent":userAgent,
                                                    "Referer":pan1.absoluteString], callback: { _ in
                                                        loadPage(url: pan3, header: ["Accept-Language":"zh-cn",
                                                                                                "Upgrade-Insecure-Requests":"1",
                                                                                                "Accept-Encoding":"gzip, deflate",
                                                                                                "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                                                                                "User-Agent":userAgent,
                                                                                                "Referer":pan2URL.absoluteString], callback: { _ in
                                                                                                    self?.readDownloadLinkList()
                                                        })
            })
        }
    }
    
    func readDownloadLinkList() {
        let url = URL(string: "https://\(mainHost)/ajax.php")!
        var pageRequest = PCDownloadRequest(headFields: ["Connection":"keep-alive",
                                                         "Referer":pan3URL.absoluteString,
                                                         "Accept-Language":"zh-cn",
                                                         "Origin":"https://\(mainHost)",
            "Accept":"text/plain, */*; q=0.01",
            "X-Requested-With":"XMLHttpRequest",
            "Content-Type":"application/x-www-form-urlencoded; charset=UTF-8",
            "Accept-Encoding":"gzip, deflate",
            "User-Agent":userAgent], url: url, method: HTTPMethod.post, body: "action=load_down_addr2&file_id=\(fileNumber)".data(using: .utf8), uuid: UUID(), friendName: self.friendName)
        pageRequest.downloadFinished = { task in
            guard let data = task.pack.revData else {
                self.downloadFinished()
                return
            }
            
            guard let html = String(data: data, encoding: .utf8), let list = self.parserFileLinkList(body: html), list.count > 0 else {
                self.downloadFinished()
                print("**************** file download link list not found ****************")
                return
            }
            
            self.read2DownloadLink(url: list.first!)
        }
        pageRequest.isFileDownloadTask = false
        pageRequest.riffle = self
        PCDownloadManager.share.add(request: pageRequest)
    }
    
    func read2DownloadLink(url: URL) {
        var pageRequest = PCDownloadRequest(headFields: ["Connection":"keep-alive",
                                                         "Referer":pan3URL.absoluteString,
                                                         "Accept-Language":"zh-cn",
                                                         "Origin":"https://\(mainHost)",
            "Accept":"text/plain, */*; q=0.01",
            "X-Requested-With":"XMLHttpRequest",
            "Content-Type":"application/x-www-form-urlencoded; charset=UTF-8",
            "Accept-Encoding":"gzip, deflate",
            "User-Agent":userAgent], url: url, method: HTTPMethod.get, body: nil, uuid: UUID(), friendName: self.friendName)
        pageRequest.downloadFinished = { task in
            guard let data = task.pack.revData else {
                self.downloadFinished()
                return
            }
            
            guard let html = String(data: data, encoding: .utf8), let list = self.parserDownloadLink(body: html), list.count > 0 else {
                self.downloadFinished()
                print("**************** file download link list not found ****************")
                return
            }
            
            self.downloadFile(urls: list)
        }
        pageRequest.isFileDownloadTask = false
        pageRequest.riffle = self
        PCDownloadManager.share.add(request: pageRequest)
    }
    
    func parserFileLinkList(body: String) -> [URL]? {
        let regx = try? NSRegularExpression(pattern: #"[^"]+file_id=\w+&sign=[^"]+"#, options: NSRegularExpression.Options.caseInsensitive)
        let strNS = body as NSString
        if let results = regx?.matches(in: body, options: NSRegularExpression.MatchingOptions.reportProgress, range: NSRange(location: 0, length: strNS.length)) {
            return results.map({
                let link = "http://\(mainHost)/\(strNS.substring(with: $0.range))"
                let url = URL(string: link)
                print("-------- file link: \(url?.absoluteString ?? "nil")")
                return url ?? nil
            }).filter({ $0 != nil }).map({ $0! })
        }
        return nil
    }
    
    func parserDownloadLink(body: String) -> [URL]? {
        let regx = try? NSRegularExpression(pattern: "http:\\/\\/[^\"]+", options: NSRegularExpression.Options.caseInsensitive)
        let strNS = body as NSString
        if let results = regx?.matches(in: body, options: NSRegularExpression.MatchingOptions.reportProgress, range: NSRange(location: 0, length: strNS.length)) {
            return results.map({
                let url = URL(string: strNS.substring(with: $0.range))
                print("-------- file link: \(url?.absoluteString ?? "nil")")
                return url ?? nil
            }).filter({ $0 != nil }).map({ $0! })
        }
        return nil
    }
    
    func downloadFile(urls: [URL]) {
        var fileDownloadRequest = PCDownloadRequest(headFields: ["Connection":"keep-alive",
                                                                 "Upgrade-Insecure-Requests":"1",
                                                                 "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                                                 "User-Agent":userAgent,
                                                                 "Referer":self.pan3URL.absoluteString,
                                                                 "Accept-Language":"zh-cn",
                                                                 "Accept-Encoding":"gzip, deflate"], url: urls[0], method: .get, body: nil, uuid: uuid, friendName: self.friendName)
        fileDownloadRequest.downloadStateUpdate = nil
        fileDownloadRequest.downloadFinished = { pack in
            print(pack.pack.revData?.debugDescription ?? "\n%%%%%%%%%%%%%%%%%%%%%% No data! %%%%%%%%%%%%%%%%%%%%%%")
            if let data = pack.pack.revData, let str = String(data: data, encoding: .utf8) {
                print("%%%%%%%%%%%%%%%%%%%%%% data %%%%%%%%%%%%%%%%%%%%%%\n")
                print(str)
                print("%%%%%%%%%%%%%%%%%%%%%% data %%%%%%%%%%%%%%%%%%%%%%")
            }
            
            if let response = pack.task.response as? HTTPURLResponse, response.statusCode == 503, urls.count > 0 {
                print("------------- 503x Found -------------")
                print("------------- Go Next Link -------------")
                self.downloadFile(urls: urls.dropFirst().map({ $0 }))
            }   else    {
                FileManager.default.save(pack: pack)
                self.downloadFinished()
            }
        }
        fileDownloadRequest.riffle = self
        PCDownloadManager.share.add(request: fileDownloadRequest)
    }
}


