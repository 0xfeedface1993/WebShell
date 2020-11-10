//
//  ColorDx.swift
//  WebShellExsample
//
//  Created by JohnConner on 2020/1/12.
//  Copyright © 2020 ascp. All rights reserved.
//

#if os(macOS)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

class ColorDx: PCWebRiffle {
    /// 文件名，从页面获取
    var fileName = ""
    var fileMain = ""
    /// 文件ID
    var fileNumber = ""
    /// 首页，因为会出现重定向的问题，先写死，后期解决这个问题
    var pageOne : URL {
        return URL(string: "http://\(mainHost)/file/\(fileMain).html")!
    }
    /// 中转页面，重定向问题
    var pageTwo : URL {
        return URL(string: "http://\(mainHost)/down/\(fileMain).html")!
    }
    
    let mainHost = "www.coolcloudx.com"
    
    /// 初始化
    ///
    /// - Parameter urlString: 下载首页地址
    public required init(urlString: String) {
        super.init()
        mainURL = URL(string: urlString)
        /// 从地址中截取文件id
        guard let num = urlString.components(separatedBy: "/").last?.components(separatedBy: ".").first else {
            print("<<<<< not find fileid : \(urlString)")
            return
        }
        
        fileMain = num
        self.host = .color
    }
    
    override public func begin() {
        loadColorPanSequence()
    }
    
    /// 启动序列
    func loadColorPanSequence() {
        func loadPage(url: URL, header:[String:String] = [:], callback: ((PCDownloadTask) -> ())?) {
            var pageRequest = PCDownloadRequest(headFields: header, url: url, method: HTTPMethod.get, body: nil, uuid: UUID(), friendName: self.friendName)
            pageRequest.downloadFinished = { task in
               callback?(task)
            }
            pageRequest.isFileDownloadTask = false
            pageRequest.riffle = self
            PCDownloadManager.share.add(request: pageRequest)
        }
        
        loadPage(url: pageOne) { [weak self] _ in
            guard let pageOne = self?.pageOne, let pageTwo = self?.pageTwo else {
                self?.downloadFinished()
                return
            }
            loadPage(url: pageTwo, header: ["Accept-Language":"zh-cn",
                                               "Upgrade-Insecure-Requests":"1",
                                               "Accept-Encoding":"gzip, deflate",
                                               "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                               "User-Agent":userAgent,
                                               "Referer":pageOne.absoluteString], callback: { task in
                                                guard let data = task.pack.revData else {
                                                    self?.downloadFinished()
                                                    return
                                                }
                                                
                                                guard let html = String(data: data, encoding: .utf8), let fileid = self?.parserFileNumber(body: html)?.first else {
                                                    self?.downloadFinished()
                                                    print("**************** file download link list not found ****************")
                                                    return
                                                }
                                                
                                                self?.fileNumber = fileid
                                                self?.readDownloadLinkList()
                                                
            })
        }
    }
    
    func readDownloadLinkList() {
        let url = URL(string: "http://\(mainHost)/ajax.php")!
        var pageRequest = PCDownloadRequest(headFields: ["Connection":"keep-alive",
                                                         "Referer":pageTwo.absoluteString,
                                                         "Accept-Language":"zh-cn",
                                                         "Origin":"http://\(mainHost)",
                                                         "Accept":"text/plain, */*; q=0.01",
                                                         "X-Requested-With":"XMLHttpRequest",
                                                         "Content-Type":"application/x-www-form-urlencoded; charset=UTF-8",
                                                         "Accept-Encoding":"gzip, deflate",
                                                         "User-Agent":userAgent], url: url, method: HTTPMethod.post, body: "action=load_down_addr1&file_id=\(fileNumber)".data(using: .utf8), uuid: UUID(), friendName: self.friendName)
        pageRequest.downloadFinished = { [weak self] task in
            guard let data = task.pack.revData else {
                self?.downloadFinished()
                return
            }
            
            guard let html = String(data: data, encoding: .utf8), let list = self?.parserFileLinkList(body: html)?.first else {
                self?.downloadFinished()
                print("**************** file download link list not found ****************")
                return
            }
            
            self?.downloadFile(url: list)
        }
        pageRequest.isFileDownloadTask = false
        pageRequest.riffle = self
        PCDownloadManager.share.add(request: pageRequest)
    }
    
    func parserFileLinkList(body: String) -> [URL]? {
        let regx = try? NSRegularExpression(pattern: "cd[^\"]+", options: NSRegularExpression.Options.caseInsensitive)
        let strNS = body as NSString
        if let results = regx?.matches(in: body, options: NSRegularExpression.MatchingOptions.reportProgress, range: NSRange(location: 0, length: strNS.length)) {
            return results.map({
                let url = URL(string: "http://\(mainHost)/\(strNS.substring(with: $0.range))")
                print("-------- file link: \(url?.absoluteString ?? "nil")")
                return url ?? nil
            }).filter({ $0 != nil }).map({ $0! })
        }
        return nil
    }
    
    func parserFileNumber(body: String) -> [String]? {
        //load_down_addr1(\'906307\')
        let regx = try? NSRegularExpression(pattern: "load_down_addr1([^)]+[\\d]+[^)]+)", options: NSRegularExpression.Options.caseInsensitive)
        let strNS = body as NSString
        if let results = regx?.matches(in: body, options: NSRegularExpression.MatchingOptions.reportProgress, range: NSRange(location: 0, length: strNS.length)) {
            return results.map({
                let mass = strNS.substring(with: $0.range)
                let regy = try! NSRegularExpression(pattern: "\\d{5,}", options: NSRegularExpression.Options.caseInsensitive)
                guard let r = regy.firstMatch(in: mass, options: .reportProgress, range: NSRange(location: 0, length: $0.range.length)) else {
                    return nil
                }
                let ass = (mass as NSString).substring(with: r.range)
                print("-------- file id: \(ass)")
                return ass
            }).filter({ $0 != nil }).map({ $0! })
        }
        return nil
    }
    
    func downloadFile(url: URL) {
        var fileDownloadRequest = PCDownloadRequest(headFields: ["Connection":"keep-alive",
                                                                 "Upgrade-Insecure-Requests":"1",
                                                                 "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                                                 "User-Agent":userAgent,
                                                                 "Referer":self.pageTwo.absoluteString,
                                                                 "Accept-Language":"zh-cn",
                                                                 "Accept-Encoding":"gzip, deflate"], url: url, method: .get, body: nil, uuid: uuid, friendName: self.friendName)
        fileDownloadRequest.downloadStateUpdate = nil
        fileDownloadRequest.downloadFinished = { [weak self] pack in
            print(pack.pack.revData?.debugDescription ?? "\n%%%%%%%%%%%%%%%%%%%%%% No data! %%%%%%%%%%%%%%%%%%%%%%")
            if let data = pack.pack.revData, let str = String(data: data, encoding: .utf8) {
                print("%%%%%%%%%%%%%%%%%%%%%% data %%%%%%%%%%%%%%%%%%%%%%\n")
                print(str)
                print("%%%%%%%%%%%%%%%%%%%%%% data %%%%%%%%%%%%%%%%%%%%%%")
            }
            
            if let response = pack.task.response as? HTTPURLResponse, let next = response.allHeaderFields["Location"] as? String, let downloadFileURL = URL(string: next) {
                print("------------- Go Next Link -------------")
                self?.go(url: downloadFileURL)
            }   else    {
                self?.downloadFinished()
            }
        }
        fileDownloadRequest.riffle = self
        PCDownloadManager.share.add(request: fileDownloadRequest)
    }
    
    func go(url: URL) {
        var fileDownloadRequest = PCDownloadRequest(headFields: ["Connection":"keep-alive",
                                                                 "Upgrade-Insecure-Requests":"1",
                                                                 "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                                                 "User-Agent":userAgent,
                                                                 "Referer":self.pageTwo.absoluteString,
                                                                 "Accept-Language":"zh-cn",
                                                                 "Accept-Encoding":"gzip, deflate"], url: url, method: .get, body: nil, uuid: uuid, friendName: self.friendName)
        fileDownloadRequest.downloadStateUpdate = nil
        fileDownloadRequest.downloadFinished = { [weak self] pack in
            print(pack.pack.revData?.debugDescription ?? "\n%%%%%%%%%%%%%%%%%%%%%% No data! %%%%%%%%%%%%%%%%%%%%%%")
            
            if let response = pack.task.response as? HTTPURLResponse, response.statusCode == 302, let next = response.allHeaderFields["Location"] as? String, let downloadFileURL = URL(string: next) {
                print("------------- 302 Found -------------")
                print("------------- Go Next Link -------------")
                self?.go(url: downloadFileURL)
            }   else    {
                if let data = pack.pack.revData, let str = String(data: data, encoding: .utf8) {
                    print("%%%%%%%%%%%%%%%%%%%%%% data %%%%%%%%%%%%%%%%%%%%%%\n")
                    print(str)
                    print("%%%%%%%%%%%%%%%%%%%%%% data %%%%%%%%%%%%%%%%%%%%%%")
                }
                FileManager.default.save(pack: pack)
                self?.downloadFinished()
            }
        }
        fileDownloadRequest.riffle = self
        PCDownloadManager.share.add(request: fileDownloadRequest)
    }
}
