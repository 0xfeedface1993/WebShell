//
//  XunNiu.swift
//  WebShellExsample
//
//  Created by virus1994 on 2018/12/28.
//  Copyright © 2018 ascp. All rights reserved.
//

#if os(macOS)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

class XunNiu: PCWebRiffle {
    var fileNumber = ""
    let hostName = "www.xun-niu.com"
    
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
            host = .xunniu
        }
    }
    
    override func begin() {
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
            ], url: url, method: HTTPMethod.post, body: "action=load_down_addr1&file_id=\(fileNumber)".data(using: .utf8)!, uuid: UUID())
        request.downloadFinished = { task in
            guard let data = task.pack.revData else {
                self.downloadFinished()
                return
            }
            
            guard let str = String(data: data, encoding: .utf8) else {
                self.downloadFinished()
                return
            }
            
            guard let link = self.parserFileLink(body: str) else {
                self.downloadFinished()
                return
            }
            
            self.download(fileURL: link)
        }
        request.isFileDownloadTask = false
        request.riffle = self
        PCDownloadManager.share.add(request: request)
    }
    
    func download(fileURL: URL) {
        var fileRequest = PCDownloadRequest(headFields: [
            "Host":"\(fileURL.host ?? ""):\(fileURL.port ?? 80)",
            "Upgrade-Insecure-Requests":"1",
            "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_2) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.0.2 Safari/605.1.15",
            "Referer":"http://\(hostName)/down-\(fileNumber).html",
            "Accept-Language":"zh-cn",
            "Accept-Encoding":"gzip, deflate",
            "Connection": "keep-alive"
            ], url: fileURL, method: HTTPMethod.get, body: nil, uuid: uuid)
        fileRequest.downloadFinished = { task in
            print(task.pack.revData?.debugDescription ?? "%%%%%%%%%%%%%%%%%%%%%% No data! %%%%%%%%%%%%%%%%%%%%%%")
            
            defer {
                self.downloadFinished()
            }
            
            if let data = task.pack.revData, let str = String(data: data, encoding: .utf8) {
                print("%%%%%%%%%%%%%%%%%%%%%% data %%%%%%%%%%%%%%%%%%%%%%\n")
                print(str)
                print("%%%%%%%%%%%%%%%%%%%%%% data %%%%%%%%%%%%%%%%%%%%%%")
            }
            
            FileManager.default.save(pack: task)
        }
        fileRequest.riffle = self
        PCDownloadManager.share.add(request: fileRequest)
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
