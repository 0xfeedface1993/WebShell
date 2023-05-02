//
//  Links.swift
//  WebShellExsample
//
//  Created by john on 2023/3/29.
//  Copyright © 2023 ascp. All rights reserved.
//

import Foundation
#if canImport(Durex)
import Durex
#endif
import Combine

public struct PHPFileDownload {
    let url: String
    let refer: String
    
    func make() throws -> URLRequest {
        try URLRequestBuilder(url)
            .method(.get)
            .add(value: "1", forKey: "Upgrade-Insecure-Requests")
            .add(value: fullAccept, forKey: "Accept")
            .add(value: userAgent, forKey: "User-Agent")
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
            .add(value: fullAccept, forKey: "accept")
            .add(value: userAgent, forKey: "user-agent")
            .add(value: refer, forKey: "referer")
            .add(value: "zh-CN,zh-Hans;q=0.9", forKey: "accept-language")
            .build()
    }
}

public struct DLPhpMatch {
    let url: String
    let pattern = "https?://[^\\s]+/dl\\w*\\.php\\?[^\"]+"
    
    func extract() throws -> [URL] {
        if #available(iOS 16.0, macOS 13.0, *) {
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

public struct FileGeneralLinkMatch {
    let html: String
    let pattern = "\"(https?://[^\"]+)\""
    
    func extract() throws -> [URL] {
        if #available(iOS 16.0, macOS 13.0, *) {
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

public struct StringParserDataTask {
    let request: URLRequest
    let encoding: String.Encoding
    
    func publisher() -> AnyPublisher<String, Error> {
        SessionPool
            .context(forKey: request.hostKey())
            .flatMap { context in
                context
                    .data(with: request)
                    .tryMap {
                        guard let text = String(data: $0, encoding: encoding) else {
                            throw ShellError.decodingFailed(encoding)
                        }
                        return text
                    }
            }
#if DEBUG
            .follow {
                print(">>> [\(type(of: self))] utf8 text: \($0)")
            }
#endif
            .eraseToAnyPublisher()
    }
}

/// 查找`dl.php`的普通限速下载链接，生成下载请求，可能会有多个下载请求
public struct PHPLinks: Condom {
    public typealias Input = URLRequest
    public typealias Output = [URLRequest]
    
    public init() { }
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        StringParserDataTask(request: inputValue, encoding: .utf8)
            .publisher()
            .tryMap { try DLPhpMatch(url: $0).extract() }
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

/// 查找http下载链接，用双扩号引起来的链接"https://xxxxx"，生成下载请求，可能会有多个下载请求
public struct GeneralLinks: Condom {
    public typealias Input = URLRequest
    public typealias Output = [URLRequest]
    
    public init() { }
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        StringParserDataTask(request: inputValue, encoding: .utf8)
            .publisher()
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
