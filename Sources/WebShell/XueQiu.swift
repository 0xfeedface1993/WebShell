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

#if canImport(Durex)
import Durex
#endif
import Combine

public enum ShellError: Error {
    case badURL(String?)
    case emptyData
    case emptyRequest
    case fileNotExist(URL)
    case invalidDestination
    case noFileID
}

extension URLSession {
    public func dataTask(_ request: URLRequest) -> Future<Data, Error> {
        Future { promise in
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let data = data else {
                    promise(.failure(ShellError.emptyData))
                    return
                }
                
                promise(.success(data))
            }.resume()
        }
    }
    
    public func downloadTask(_ request: URLRequest) -> Future<(URL, URLResponse), Error> {
        Future { promise in
            URLSession.shared.downloadTask(with: request, completionHandler: { url, response, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let url = url, let response = response else {
                    promise(.failure(ShellError.emptyData))
                    return
                }
                
                promise(.success((url, response)))
            }).resume()
        }
    }
}

public struct XueQiuSaver: Condom {
    public typealias Input = [URLRequest]
    public typealias Output = URL
    
    public init() {
        
    }
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        guard let request = inputValue.first else {
            return Fail(error: ShellError.emptyRequest).eraseToAnyPublisher()
        }
        return URLSession
            .shared
            .downloadTask(request)
            .tryMap {
                try MoveToDownloads(tempURL: $0.0, suggestedFilename: $0.1.suggestedFilename).move()
            }
            .eraseToAnyPublisher()
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
}

public struct MoveToDownloads {
    let tempURL: URL
    let suggestedFilename: String?
    
    func move() throws -> URL {
        guard FileManager.default.fileExists(atPath: tempURL.path) else {
            throw ShellError.fileNotExist(tempURL)
        }
        
        let filename = suggestedFilename ?? tempURL.lastPathComponent
        guard let folder = FileManager.default.urls(for: .downloadsDirectory, in: .allDomainsMask).first else {
            throw ShellError.invalidDestination
        }
        
        let destination = folder.appendingPathComponent(filename)
        try FileManager.default.moveItem(at: tempURL, to: destination)
        print(">>> move file to \(destination)")
        return destination
    }
}

public struct XueQiuLinks: Condom {
    public typealias Input = URLRequest
    public typealias Output = [URLRequest]
    
    public init() {
        
    }
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        URLSession.shared
            .dataTask(inputValue)
            .compactMap({
                String(data: $0, encoding: .utf8)
            })
            .tryMap {
                try DLPhpMatch(url: $0).extract()
            }
            .map { urls in
                urls.compactMap {
                    do {
                        return try PHPFileDownload(url: $0.absoluteString, refer: refer(inputValue)).make()
                    }   catch   {
                        print(">>> download url make failed \(error)")
                        return nil
                    }
                }
            }
            .eraseToAnyPublisher()
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
    
    private func refer(_ request: URLRequest) -> String {
        guard let path = request.url, let scheme = path.scheme, let host = path.host else {
            return ""
        }
        
        return "\(scheme)://\(host)"
    }
}

public struct XueQiuDownPage: Condom {
    public typealias Input = String
    public typealias Output = URLRequest
    
    public init() {
        
    }
    
    public func publisher(for inputValue: String) -> AnyPublisher<Output, Error> {
        do {
            return AnyValue(try request(inputValue)).eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
    
    func request(_ string: String) throws -> URLRequest {
        guard let url = URL(string: string),
                let component = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw ShellError.badURL(string)
        }
        
        guard let host = component.host, let scheme = component.scheme else {
            throw ShellError.badURL(string)
        }
        
        let fileid = try FileIDMatch(url: string).extract()
        return try DownPage(fileid: fileid, scheme: scheme, host: host).make()
    }
}

public struct DownPage {
    let fileid: String
    let scheme: String
    let host: String
    
    func make() throws -> URLRequest {
        let http = "\(scheme)://\(host)"
        let refer = "\(http)/down-\(fileid).html"
        let url = "\(http)/ajax.php"
        return try URLRequestBuilder(url)
            .method(.post)
            .add(value: "text/plain, */*; q=0.01", forKey: "Accept")
            .add(value: "XMLHttpRequest", forKey: "X-Requested-With")
            .add(value: "zh-CN,zh-Hans;q=0.9", forKey: "Accept-Language")
            .add(value: "application/x-www-form-urlencoded; charset=UTF-8", forKey: "Content-Type")
            .add(value: http, forKey: "Origin")
            .add(value: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.1 Safari/605.1.15", forKey: "User-Agent")
            .add(value: refer, forKey: "Referer")
            .body("action=load_down_addr1&file_id=\(fileid)".data(using: .utf8) ?? Data())
            .build()
    }
}

public struct FileIDMatch {
    let url: String
    let pattern = "\\-(\\w+)\\.\\w+"
    
    func extract() throws -> String {
        if #available(macOS 13.0, *) {
            let regx = try Regex(pattern)
            guard let match = url.firstMatch(of: regx),
                    let fileid = match.output[1].substring else {
                throw ShellError.badURL(url)
            }
            return String(fileid)
        } else {
            // Fallback on earlier versions
            let regx = try NSRegularExpression(pattern: pattern)
            let nsString = url as NSString
            guard let result = regx.firstMatch(in: url, range: .init(location: 0, length: nsString.length)) else {
                throw ShellError.badURL(url)
            }
            return regx.replacementString(for: result, in: url, offset: 0, template: "$1")
        }
    }
}

public struct DLPhpMatch {
    let url: String
    let pattern = "https?://[^\\s]+/dl\\.php\\?\\w+"
    
    func extract() throws -> [URL] {
        if #available(macOS 13.0, *) {
            let regx = try Regex(pattern)
            let urls = url.matches(of: regx).compactMap({ $0.output[0].substring })
            return urls.compactMap { value in
                URL(string: String(value))
            }
        } else {
            // Fallback on earlier versions
            let regx = try NSRegularExpression(pattern: pattern)
            let nsString = url as NSString
            let range = NSRange(location: 0, length: nsString.length)
            return regx.matches(in: url, range: range)
                .map { result in
                    regx.replacementString(for: result, in: url, offset: 0, template: "$0")
                }
                .compactMap(URL.init(string:))
        }
    }
}

public struct PHPFileDownload {
    let url: String
    let refer: String
    
    func make() throws -> URLRequest {
        try URLRequestBuilder(url)
            .method(.get)
            .add(value: "1", forKey: "Upgrade-Insecure-Requests")
            .add(value: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forKey: "Accept")
            .add(value: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.1 Safari/605.1.15", forKey: "User-Agent")
            .add(value: refer, forKey: "Referer")
            .add(value: "zh-CN,zh-Hans;q=0.9", forKey: "Accept-Language")
            .build()
    }
}

public struct GeneralFileDownload {
    let url: String
    let refer: String
    
    func make() throws -> URLRequest {
        try URLRequestBuilder(url)
            .method(.get)
            .add(value: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forKey: "accept")
            .add(value: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.1 Safari/605.1.15", forKey: "user-agent")
            .add(value: refer, forKey: "referer")
            .add(value: "zh-CN,zh-Hans;q=0.9", forKey: "accept-language")
            .build()
    }
}

extension Array: ContextValue where Element == URLRequest {
    public var valueDescription: String {
        "\(self)"
    }
}

public struct AppendDownPath: Condom {
    public typealias Input = String
    public typealias Output = URLRequest
    
    public init() {
        
    }
    
    public func publisher(for inputValue: String) -> AnyPublisher<Output, Error> {
        do {
            return AnyValue(try remake(inputValue)).eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
    
    func remake(_ string: String) throws -> URLRequest {
        guard let url = URL(string: string),
                var component = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw ShellError.badURL(string)
        }
        
        component.path = "/d\(component.path)"
        
        guard let next = component.url?.absoluteString else {
            throw ShellError.badURL(component.path)
        }
        
        return try URLRequestBuilder(next)
            .add(value: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forKey: "Accept")
            .add(value: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.1 Safari/605.1.15", forKey: "user-agent")
            .add(value: string, forKey: "referer")
            .add(value: "zh-CN,zh-Hans;q=0.9", forKey: "Accept-Language")
            .build()
    }
}

public struct FileIDStringInDomSearch: Condom {
    public typealias Input = URLRequest
    public typealias Output = String
    
    public init() {
        
    }
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        URLSession.shared
            .dataTask(inputValue)
            .compactMap({
                String(data: $0, encoding: .utf8)
            })
            .tryMap { html in
                try FileIDInFunctionParameter(html: html).extract()
            }
            .eraseToAnyPublisher()
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
}

public struct GeneralDownPage {
    let scheme: String
    let fileid: String
    let host: String
    let refer: String
    
    func make() throws -> URLRequest {
        let http = "\(scheme)://\(host)"
        let url = "\(http)/ajax.php"
        return try URLRequestBuilder(url)
            .method(.post)
            .add(value: "text/plain, */*; q=0.01", forKey: "accept")
            .add(value: "XMLHttpRequest", forKey: "x-requested-with")
            .add(value: "zh-CN,zh-Hans;q=0.9", forKey: "accept-language")
            .add(value: "application/x-www-form-urlencoded; charset=UTF-8", forKey: "content-type")
            .add(value: http, forKey: "Origin")
            .add(value: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.1 Safari/605.1.15", forKey: "user-agent")
            .add(value: refer, forKey: "referer")
            .body("action=load_down_addr1&file_id=\(fileid)".data(using: .utf8) ?? Data())
            .build()
    }
}

public struct GeneralDownPageByID: Condom {
    public typealias Input = String
    public typealias Output = URLRequest
    
    let scheme: String
    let host: String
    let refer: String
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        do {
            return AnyValue(try GeneralDownPage(scheme: scheme, fileid: inputValue, host: host, refer: refer).make()).eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
}

public struct FileIDStringInDomSearchGroup: Condom {
    public typealias Input = URLRequest
    public typealias Output = URLRequest
    
    public init() {
        
    }
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        do {
            return try search(inputValue)
                .publisher(for: inputValue)
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
    
    private func search(_ request: URLRequest) throws -> AnyCondom<Input, Output> {
        guard let url = request.url,
                let component = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw ShellError.badURL(request.url?.absoluteString ?? "")
        }
        
        guard let host = component.host, let scheme = component.scheme else {
            throw ShellError.badURL(url.absoluteString)
        }
        
        let searchid = FileIDStringInDomSearch()
        let page = GeneralDownPageByID(scheme: scheme, host: host, refer: url.absoluteString)
        
        return searchid.join(page)
    }
}

public struct FindGeneralFileLinks: Condom {
    public typealias Input = URLRequest
    public typealias Output = [URLRequest]
    
    public init() {
        
    }
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        URLSession.shared
            .dataTask(inputValue)
            .compactMap {
                String(data: $0, encoding: .utf8)
            }
            .tryMap { html in
                try FileGeneralLinkMatch(html: html).extract()
            }
            .map { urls in
                let refer = inputValue.url?.absoluteString ?? ""
                return urls.compactMap {
                    do {
                        return try GeneralFileDownload(url: $0.absoluteString, refer: refer).make()
                    }   catch   {
                        print(">>> download url make failed \(error)")
                        return nil
                    }
                }
            }
            .eraseToAnyPublisher()
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
}

struct FileIDInFunctionParameter {
    let html: String
    let pattern = "load_down_addr1\\('([\\w\\d]+)'\\)"
    
    func extract() throws -> String {
        if #available(macOS 13.0, *) {
            let regx = try Regex(pattern)
            guard let fileid = html.firstMatch(of: regx)?.output[1].substring else {
                throw ShellError.noFileID
            }
            return String(fileid)
        } else {
            // Fallback on earlier versions
            let regx = try NSRegularExpression(pattern: pattern)
            let nsString = html as NSString
            let range = NSRange(location: 0, length: nsString.length)
            guard let fileid = regx.firstMatch(in: html, range: range) else {
                throw ShellError.noFileID
            }
            return regx.replacementString(for: fileid, in: html, offset: 0, template: "$1")
        }
    }
}

public struct FileGeneralLinkMatch {
    let html: String
    let pattern = "\"(https?://[^\"]+)\""
    
    func extract() throws -> [URL] {
        if #available(macOS 13.0, *) {
            let regx = try Regex(pattern)
            let urls = html.matches(of: regx).compactMap({ $0.output[1].substring })
            return urls.compactMap { value in
                URL(string: String(value))
            }
        } else {
            // Fallback on earlier versions
            let regx = try NSRegularExpression(pattern: pattern)
            let nsString = html as NSString
            let range = NSRange(location: 0, length: nsString.length)
            return regx.matches(in: html, range: range)
                .map { result in
                    regx.replacementString(for: result, in: html, offset: 0, template: "$1")
                }
                .compactMap(URL.init(string:))
        }
    }
}
