//
//  BusPan.swift
//  WebShellExsample
//
//  Created by virus1994 on 2019/11/10.
//  Copyright © 2019 ascp. All rights reserved.
//

#if os(macOS)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

class BusPan: PCWebRiffle {
    let hostName = "www.tadaigou.com"
    override public var scriptName: String {
        return "buspan"
    }
    var filePath = ""
    var fileID = ""
    var filePageURL : URL {
        return URL(string: "http://\(hostName)/file/\(filePath).html")!
    }
    
    var downPageURL : URL {
        return URL(string: "http://\(hostName)/down/\(filePath).html")!
    }
    
    var ajaxPageURL : URL {
        return URL(string: "http://\(hostName)/ajax.php")!
    }
    
    /// 初始化
    ///
    /// - Parameter urlString: 下载首页地址
    public init(urlString: String) {
        super.init()
        mainURL = URL(string: urlString)
        guard let lastPath = mainURL?.lastPathComponent.components(separatedBy: ".").first else {
            print("------------- Paage URL Invaliade -------------")
            print(urlString)
            return
        }
        
        filePath = lastPath
    }
    
    override public func begin() {
        let heads = ["Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                     "User-Agent": userAgent,
                     "Accept-Language": "zh-cn",
                     "Accept-Encoding": "gzip, deflate",
                     "Connection": "keep-alive"]
        let url = filePageURL
        var pageRequest = PCDownloadRequest(headFields: heads, url: url, method: HTTPMethod.get, body: nil, uuid: UUID(), friendName: "")
        pageRequest.downloadFinished = { task in
            guard let data = task.pack.revData else {
                self.downloadFinished()
                return
            }
            
            guard let html = String(data: data, encoding: .utf8), let id = self.parserFileID(body: html) else {
                self.downloadFinished()
                print("**************** file download link list not found ****************")
                return
            }
            
            self.fileID = id
            self.readDownloadLinkList()
        }
        pageRequest.isFileDownloadTask = false
        pageRequest.riffle = self
        PCDownloadManager.share.add(request: pageRequest)
    }
    
    func readDownloadLinkList() {
        let url = ajaxPageURL
        var pageRequest = PCDownloadRequest(headFields: ["Connection":"keep-alive",
                                                         "Referer":downPageURL.absoluteString,
                                                         "Accept-Language":"zh-cn",
                                                         "Origin":"http://\(hostName)",
                                                         "Accept":"text/plain, */*; q=0.01",
                                                         "X-Requested-With":"XMLHttpRequest",
                                                         "Content-Type":"application/x-www-form-urlencoded; charset=UTF-8",
                                                         "Accept-Encoding":"gzip, deflate",
                                                         "User-Agent":userAgent], url: url, method: HTTPMethod.post, body: "action=load_down_addr1&file_id=\(fileID)&vipd=0".data(using: .utf8), uuid: UUID(), friendName: self.friendName)
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
            
            self.downloadFile(urls: list)
        }
        pageRequest.isFileDownloadTask = false
        pageRequest.riffle = self
        PCDownloadManager.share.add(request: pageRequest)
    }
    
    func downloadFile(urls: [URL]) {
        if urls.count <= 0 {
            print("------------- URLs count is 0 -------------")
            self.downloadFinished()
            return
        }
        var fileDownloadRequest = PCDownloadRequest(headFields: ["Connection":"keep-alive",
                                                                 "Upgrade-Insecure-Requests":"1",
                                                                 "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                                                                 "User-Agent":userAgent,
                                                                 "Referer":downPageURL.absoluteString,
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
    
    func parserFileLinkList(body: String) -> [URL]? {
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
    
    func parserFileID(body: String) -> String? {
        let regx = try? NSRegularExpression(pattern: "add\\_ref\\([\\d]+\\)", options: NSRegularExpression.Options.caseInsensitive)
        let strNS = body as NSString
        if let result = regx?.firstMatch(in: body, options: NSRegularExpression.MatchingOptions.reportProgress, range: NSRange(location: 0, length: strNS.length)) {
            let ref = strNS.substring(with: result.range) as NSString
            let regy = try! NSRegularExpression(pattern: "\\d+", options: NSRegularExpression.Options.caseInsensitive)
            let textResult = regy.firstMatch(in: ref as String, options: NSRegularExpression.MatchingOptions.reportProgress, range: NSRange(location: 0, length: ref.length))!
            return ref.substring(with: textResult.range)
        }
        return nil
    }
}
