//
//  KuYun.swift
//  WebShellExsample
//
//  Created by JohnConner on 2020/4/19.
//  Copyright © 2020 ascp. All rights reserved.
//

import Foundation

class KuYun: PCWebRiffle {
    var fileNumber = ""
    let hostName = "www.kufile.net"
    var fileMain = ""
    
    var onePage: URL {
        return URL(string: "http://\(hostName)/file/\(fileMain).html")!
    }
    
    /// 中转页面
    var middlePage: URL {
        return URL(string: "http://\(hostName)/file/\(fileMain).html")!
    }
    
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
    }
    
    override func begin() {
        loadColorPanSequence()
    }
    
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
        
        loadPage(url: self.middlePage, header: ["Accept-Language":"zh-cn",
                                                "Upgrade-Insecure-Requests":"1",
                                                "Accept-Encoding":"gzip, deflate",
                                                "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                                "User-Agent":userAgent,
                                                "Referer":self.onePage.absoluteString], callback: { [weak self] task in
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
    
    func readDownloadLinkList() {
        let url = URL(string: "http://\(hostName)/ajax.php")!
        var pageRequest = PCDownloadRequest(headFields: ["Connection":"keep-alive",
                                                         "Referer":middlePage.absoluteString,
                                                         "Accept-Language":"zh-cn",
                                                         "Origin":"http://\(hostName)",
                                                         "Accept":"text/plain, */*; q=0.01",
                                                         "X-Requested-With":"XMLHttpRequest",
                                                         "Content-Type":"application/x-www-form-urlencoded; charset=UTF-8",
                                                         "Accept-Encoding":"gzip, deflate",
                                                         "User-Agent":userAgent], url: url, method: HTTPMethod.post, body: "action=load_down_file_user&file_id=\(fileNumber)&ms=undefined*undefined&sc=1680*1050".data(using: .utf8), uuid: UUID(), friendName: self.friendName)
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
        let regx = try? NSRegularExpression(pattern: "cd\\.[^\"]+", options: NSRegularExpression.Options.caseInsensitive)
        let strNS = body as NSString
        if let results = regx?.matches(in: body, options: NSRegularExpression.MatchingOptions.reportProgress, range: NSRange(location: 0, length: strNS.length)) {
            return results.compactMap({
                let url = URL(string: "http://\(hostName)/\(strNS.substring(with: $0.range))")
                print("-------- file link: \(url?.absoluteString ?? "nil")")
                return url ?? nil
            })
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
        var fileDownloadRequest = PCDownloadRequest(headFields: ["Host":hostName,
                                                                 "Connection":"keep-alive",
                                                                 "Upgrade-Insecure-Requests":"1",
                                                                 "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                                                 "User-Agent":userAgent,
                                                                 "Referer":self.middlePage.absoluteString,
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
                print(">>> kuyun response http header: \(response.allHeaderFields)")
                // 某些情况下，最后一个数据包会返回重定向信息，因此保存文件数据即可
                if next.contains("promo.php") {
                    FileManager.default.save(pack: pack)
                    self?.downloadFinished()
                    return
                }
                print("------------- Go Next Link -------------")
                if next.hasPrefix("http") {
                    self?.go(url: downloadFileURL)
                }   else    {
                    print(">>> invalid download URL: \(downloadFileURL)")
                    self?.downloadFinished()
                }
            }   else    {
                self?.downloadFinished()
            }
        }
        fileDownloadRequest.riffle = self
        PCDownloadManager.share.add(request: fileDownloadRequest)
    }
    
    func go(url: URL) {
        print(">>> go url: \(url)")
        var fileDownloadRequest = PCDownloadRequest(headFields: ["Connection":"keep-alive",
                                                                 "Upgrade-Insecure-Requests":"1",
                                                                 "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                                                 "User-Agent":userAgent,
                                                                 "Referer":self.middlePage.absoluteString,
                                                                 "Accept-Language":"zh-cn",
                                                                 "Accept-Encoding":"gzip, deflate"], url: url, method: .get, body: nil, uuid: uuid, friendName: self.friendName)
        fileDownloadRequest.downloadStateUpdate = nil
        fileDownloadRequest.downloadFinished = { [weak self] pack in
            print(pack.pack.revData?.debugDescription ?? "\n%%%%%%%%%%%%%%%%%%%%%% No data! %%%%%%%%%%%%%%%%%%%%%%")
            
            if let response = pack.task.response as? HTTPURLResponse, response.statusCode == 302, let next = response.allHeaderFields["Location"] as? String, let downloadFileURL = URL(string: next) {
                // 某些情况下，最后一个数据包会返回重定向信息，因此保存文件数据即可
                if next.contains("promo.php") {
                    FileManager.default.save(pack: pack)
                    self?.downloadFinished()
                    return
                }
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
