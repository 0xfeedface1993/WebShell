//
//  XueQiu.swift
//  WebShellExsample
//
//  Created by JohnConner on 2020/11/9.
//  Copyright © 2020 ascp. All rights reserved.
//

import Foundation

public class XueQiu: PCWebRiffle {
    var fileNumber = ""
    let hostName = "www.xueqiupan.com"
    
    var onePage: URL {
        return URL(string: "http://\(hostName)/file-\(fileNumber).html")!
    }
    
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
            print("-------- fileID: \(fileNumber)")
            host = .xueQiu
        }
    }
    
    public override func begin() {
        loadFileLink()
    }
    
    func loadFileLink() {
        let url = URL(string: "http://\(hostName)/ajax.php")!
        var request = PCDownloadRequest(headFields: [
             "Host":hostName,
             "Accept":"text/plain, */*; q=0.01",
             "X-Requested-With":"XMLHttpRequest",
             "Accept-Language":"zh-cn",
             "Accept-Encoding":"gzip, deflate",
             "Content-Type":"application/x-www-form-urlencoded; charset=UTF-8",
             "Origin":hostName,
             "User-Agent":userAgent,
             "Referer":"http://\(hostName)/down-\(fileNumber).html",
             "Connection":"keep-alive"
            ], url: url, method: HTTPMethod.post, body: "action=load_down_addr1&file_id=\(fileNumber)".data(using: .utf8)!, uuid: UUID(), friendName: self.friendName)
        request.downloadFinished = { [weak self] task in
            guard let data = task.pack.revData else {
                self?.downloadFinished()
                return
            }
            
            guard let str = String(data: data, encoding: .utf8) else {
                self?.downloadFinished()
                return
            }
            
            guard let link = self?.parserFileLink(body: str) else {
                self?.downloadFinished()
                return
            }
            
            self?.download(fileURL: link)
        }
        request.isFileDownloadTask = false
        request.riffle = self
        PCDownloadManager.share.add(request: request)
    }
    
    func download(fileURL: URL) {
        var fileRequest = PCDownloadRequest(headFields: [
            "Host":"\(fileURL.host ?? "")\(fileURL.port != nil ? ":\(fileURL.port!)":"")",
            "Upgrade-Insecure-Requests":"1",
            "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "User-Agent": userAgent,
            "Referer":"http://\(hostName)/down-\(fileNumber).html",
            "Accept-Language":"zh-cn",
            "Accept-Encoding":"gzip, deflate",
            "Connection": "keep-alive"
            ], url: fileURL, method: HTTPMethod.get, body: nil, uuid: uuid, friendName: self.friendName)
        fileRequest.downloadFinished = { [weak self] task in
            print(task.pack.revData?.debugDescription ?? "%%%%%%%%%%%%%%%%%%%%%% No data! %%%%%%%%%%%%%%%%%%%%%%")
            
            if let response = task.task.response as? HTTPURLResponse, response.statusCode == 302, let location = response.allHeaderFields["Location"] as? String, let fileURL = URL(string: location) {
                #if os(iOS)
                print("-------------- 302 Found, try remove task in background session --------------")
                PCDownloadManager.share.removeFromBackgroundSession(originURL: fileURL)
                #endif
                self?.downloadFor302(url: fileURL, refer: fileURL)
            }   else    {
                FileManager.default.save(pack: task)
                self?.downloadFinished()
            }
        }
        fileRequest.riffle = self
        PCDownloadManager.share.add(request: fileRequest)
    }
    
    /// 下载文件
    ///
    /// - Parameter url: 文件实际下载路径
    func downloadFor302(url: URL, refer: URL) {
        var fileDownloadRequest = PCDownloadRequest(headFields: ["Referer":refer.absoluteString,
                                                                 "Accept-Language":"zh-cn",
                                                                 "Upgrade-Insecure-Requests":"1",
                                                                 "Accept-Encoding":"gzip, deflate",
                                                                 "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                                                 "User-Agent":userAgent], url: url, method: .get, body: nil, uuid: uuid, friendName: self.friendName)
        fileDownloadRequest.downloadStateUpdate = nil
        fileDownloadRequest.downloadFinished = { [weak self] pack in
            print(pack.pack.revData?.debugDescription ?? "%%%%%%%%%%%%%%%%%%%%%% No data! %%%%%%%%%%%%%%%%%%%%%%")
            
            if let data = pack.pack.revData, let str = String(data: data, encoding: .utf8) {
                print("%%%%%%%%%%%%%%%%%%%%%% data %%%%%%%%%%%%%%%%%%%%%%\n")
                print(str)
                print("%%%%%%%%%%%%%%%%%%%%%% data %%%%%%%%%%%%%%%%%%%%%%")
            }
            
            FileManager.default.save(pack: pack)
            self?.downloadFinished()
        }
        fileDownloadRequest.riffle = self
        PCDownloadManager.share.add(request: fileDownloadRequest)
    }
    
    func parserFileLink(body: String) -> URL? {
        let regx = try? NSRegularExpression(pattern: "http:\\/\\/[^\"]+", options: NSRegularExpression.Options.caseInsensitive)
        let strNS = body as NSString
        if let result = regx?.firstMatch(in:  body, options: NSRegularExpression.MatchingOptions.reportProgress, range: NSRange(location: 0, length: strNS.length)) {
            let url = URL(string: strNS.substring(with: result.range))
            print("-------- file link: \(url?.absoluteString ?? "nil")")
            return url
        }
        return nil
    }
}
