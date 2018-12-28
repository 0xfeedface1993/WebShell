//
//  V2File.swift
//  WebShellExsample
//
//  Created by virus1994 on 2018/7/11.
//  Copyright © 2018年 ascp. All rights reserved.
//

#if os(macOS)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

class V2File: PCWebRiffle {
    struct V2LoginResult: Codable {
        var status: Int
        var msg: String
        var data: V2LData?
    }
    
    struct V2FileResult: Codable {
        var status: Int
        var msg: String
        var data: V2FData?
    }
    
    struct V2LData: Codable {
        var token: String
        var id: Int
    }
    
    struct V2FData: Codable {
        var href: String
        var user_id: Int
    }
    
    struct V2LoginUpload: Codable {
        var email: String
        var password: String
    }
    
    var fileNumber = ""
    var loginResult : V2LoginResult?
    
    var requestFileLinkURL: URL {
        return URL(string: "http://sportal.wa54.space/portal/file/download?id=" + fileNumber)!
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
            print("-------- fileNumber: \(fileNumber)")
            host = .v2file
        }
    }
    
    override public func begin() {
        login(username: "318715498@qq.com", password: "xvtingsong")
    }
    
    func login(username: String, password: String) {
        let url = URL(string: "http://sportal.wa54.space/users/login")!
        let upload = V2LoginUpload(email: username, password: password)
        let encoder = JSONEncoder()
        var loginRequest = PCDownloadRequest(headFields: [
            "Host":"sportal.wa54.space",
            "Accept":"application/json, text/plain, */*",
            "Accept-Encoding":"gzip, deflate",
            "Accept-Language":"zh-cn",
            "Content-Type":"application/json",
            "Origin":"http://sportal.wa54.space",
            "User-Agent":userAgent,
            "Connection":"keep-alive"
            ], url: url, method: HTTPMethod.post, body: try! encoder.encode(upload), uuid: UUID())
        loginRequest.downloadFinished = { task in
            guard let data = task.pack.revData else {
                return
            }
            do {
                let decoder = JSONDecoder()
                let json = try decoder.decode(V2LoginResult.self, from: data)
                if json.status != 200 {
                    print(json.msg)
                    self.downloadFinished()
                    return
                }
                self.loginResult = json
                self.readFileLink()
            }   catch   {
                print(error)
                let str = String(data: data, encoding: .utf8)
                print(str ?? "***** bad text *****")
                self.downloadFinished()
            }
        }
        loginRequest.isFileDownloadTask = false
        loginRequest.riffle = self
        PCDownloadManager.share.add(request: loginRequest)
    }
    
    func readFileLink() {
        guard let token = loginResult?.data?.token, !token.isEmpty else {
            self.downloadFinished()
            return
        }
        var readlinkRequest = PCDownloadRequest(headFields: [
            "Host":"sportal.wa54.space",
            "Origin":"http://sportal.wa54.space",
            "Accept":"application/json, text/plain, */*",
            "User-Agent":userAgent,
            "Accept-Language":"zh-cn",
            "Referer":"http://sportal.wa54.space/",
            "Accept-Encoding":"gzip, deflate",
            "Connection":"keep-alive",
            "token-auth":token
            ], url: requestFileLinkURL, method: HTTPMethod.get, body: nil, uuid: UUID())
        readlinkRequest.downloadFinished = { task in
            guard let data = task.pack.revData else {
                return
            }
            do {
                let decoder = JSONDecoder()
                let json = try decoder.decode(V2FileResult.self, from: data)
                if json.status != 200 {
                    print(json.msg)
                    self.downloadFinished()
                    return
                }
                if let fileLink = json.data?.href, let url = URL(string: fileLink) {
                    self.download(fileURL: url)
                }   else    {
                    self.downloadFinished()
                }
            }   catch   {
                print(error)
                self.downloadFinished()
            }
        }
        readlinkRequest.isFileDownloadTask = false
        readlinkRequest.riffle = self
        PCDownloadManager.share.add(request: readlinkRequest)
    }
    
    func download(fileURL: URL) {
        guard let token = loginResult?.data?.token, !token.isEmpty else {
            self.downloadFinished()
            return
        }
        var fileRequest = PCDownloadRequest(headFields: [
            "User-Agent": userAgent,
            "Accept": "*/*",
            "Host": fileURL.host ?? "download.wa54.space",
            "accept-encoding": "gzip, deflate",
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
}
