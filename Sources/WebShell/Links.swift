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

//public struct SignPHPFileDownload: DownloadRequestBuilder {
//    let url: String
//    let refer: String
//
//    func make() throws -> URLRequest {
//        try make(url, refer: refer)
//    }
//
//    public func make(_ url: String, refer: String) throws -> URLRequest {
//        try URLRequestBuilder(url)
//            .method(.get)
//            .add(value: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forKey: "accept")
//            .add(value: "cross-site", forKey: "sec-fetch-site")
//            .add(value: "document", forKey: "sec-fetch-dest")
//            .add(value: "en-US,en;q=0.9", forKey: "accept-language")
//            .add(value: "navigate", forKey: "sec-fetch-mode")
//            .add(value: userAgent, forKey: "user-agent")
//            .add(value: refer, forKey: "referer")
//            .add(value: "down_file_log=1", forKey: "Cookie")
//            .build()
//    }
//}


public struct PHPFileDownload: DownloadRequestBuilder {
    let url: String
    let refer: String
    
    func make() throws -> URLRequest {
        try make(url, refer: refer)
    }
    
    public func make(_ url: String, refer: String) throws -> URLRequest {
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

public struct DLPhpMatch: ContentMatch {
    let url: String
    let pattern = "https?://[^\\s]+/dl\\w*\\.php\\?[^\"]+"
    
    func extract() throws -> [URL] {
        try extract(url)
    }
    
    public func extract(_ text: String) throws -> [URL] {
        try URLRegularExpressionMatch(url: text, pattern: pattern, template: Templates.dollar(0))
            .extract()
    }
}

public struct CDPhpMatch: ContentMatch {
    let host: String
    let pattern = "cd\\w*\\.php\\?[^\"]+"
    
    public func extract(_ url: String) throws -> [URL] {
        let results = try URLRegularExpressionMatch(url: url, pattern: pattern, template: Templates.dollar(0))
            .extract()
        if let hostURL = URL(string: host) {
            return results
                .compactMap({ item in
                    BaseURL(url: item).replaceHost(hostURL)
                })
        }   else    {
            return results
        }
    }
}

public struct FileGeneralLinkMatch {
    let html: String
    let pattern = "\"(https?://[^\"]+)\""
    
    func extract() throws -> [URL] {
        try URLRegularExpressionMatch(url: html, pattern: pattern, template: Templates.dollar(1))
            .extract()
    }
}

public struct StringParserDataTask {
    let request: URLRequest
    let encoding: String.Encoding
    let sessionKey: AnyHashable
    
    func publisher() -> AnyPublisher<String, Error> {
        SessionPool
            .context(sessionKey)
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
                logger.info("[\(type(of: self))] utf8 text: \($0)")
            }
#endif
            .eraseToAnyPublisher()
    }
}

/// 查找`dl.php`的普通限速下载链接，生成下载请求，可能会有多个下载请求
public struct PHPLinks: SessionableCondom {
    public typealias Input = URLRequest
    public typealias Output = [URLRequest]
    
    public var key: AnyHashable
    
    public init(_ key: AnyHashable = "default") {
        self.key = key
    }
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        DownloadLinks(key, matcher: DLPhpMatch(url: ""), requestBuilder: PHPFileDownload(url: "", refer: ""))
            .publisher(for: inputValue)
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
    
    public func sessionKey(_ value: AnyHashable) -> PHPLinks {
        PHPLinks(value)
    }
}

/// 查找http下载链接，用双扩号引起来的链接"https://xxxxx"，生成下载请求，可能会有多个下载请求
public struct GeneralLinks: SessionableCondom {
    public typealias Input = URLRequest
    public typealias Output = [URLRequest]
    
    public var key: AnyHashable
    
    public init(_ key: AnyHashable = "default") {
        self.key = key
    }
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        StringParserDataTask(request: inputValue, encoding: .utf8, sessionKey: key)
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
                        logger.error("download url make failed \(error)")
                        return nil
                    }
                }
            }
        #if DEBUG
            .follow({
                logger.info("[GeneralLinks] find download links \($0)")
            })
        #endif
            .eraseToAnyPublisher()
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
    
    public func sessionKey(_ value: AnyHashable) -> GeneralLinks {
        GeneralLinks(value)
    }
}

//public struct SignLinks: SessionableCondom {
//    public typealias Input = URLRequest
//    public typealias Output = [URLRequest]
//    
//    public var key: AnyHashable
//    
//    public init(_ key: AnyHashable = "default") {
//        self.key = key
//    }
//    
//    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
//        StringParserDataTask(request: inputValue, encoding: .utf8, sessionKey: key)
//            .publisher()
//            .tryMap { html in
//                try FileGeneralLinkMatch(html: html).extract()
//            }
//            .map { urls in
//                guard let inputURL = inputValue.url else {
//#if DEBUG
//                    logger.error("[\(type(of: self))] inputValue url is nil. \(inputValue)")
//#endif
//                    return []
//                }
//                let refer = hostOnly(inputURL).absoluteString
//                return urls.compactMap {
//                    do {
//                        return try SignPHPFileDownload(url: $0.absoluteString, refer: refer).make()
//                    }   catch   {
//                        logger.error("download url make failed \(error)")
//                        return nil
//                    }
//                }
//            }
//        #if DEBUG
//            .follow({
//                logger.error("[\(type(of: self))] find download links \($0)")
//            })
//        #endif
//            .eraseToAnyPublisher()
//    }
//    
//    private func hostOnly(_ url: URL) -> URL {
//        var next = url
//        next.deletePathExtension()
//        return next
//    }
//    
//    public func empty() -> AnyPublisher<Output, Error> {
//        Empty().eraseToAnyPublisher()
//    }
//    
//    public func sessionKey(_ value: AnyHashable) -> SignLinks {
//        SignLinks(value)
//    }
//}

/// 查找`dl.php`的普通限速下载链接，生成下载请求，可能会有多个下载请求
public struct DownloadLinks<Matcher: ContentMatch, RequestBuilder: DownloadRequestBuilder>: SessionableCondom {
    public typealias Input = URLRequest
    public typealias Output = [URLRequest]
    
    public var key: AnyHashable
    public let matcher: Matcher
    public let requestBuilder: RequestBuilder
    
    public init(_ key: AnyHashable = "default", matcher: Matcher, requestBuilder: RequestBuilder) {
        self.key = key
        self.matcher = matcher
        self.requestBuilder = requestBuilder
    }
    
    public func matcher<T: ContentMatch>(_ value: T) -> DownloadLinks<T, RequestBuilder> {
        DownloadLinks<T, RequestBuilder>(key, matcher: value, requestBuilder: requestBuilder)
    }
    
    public func builder<T: DownloadRequestBuilder>(_ value: T) -> DownloadLinks<Matcher, T> {
        DownloadLinks<Matcher, T>(key, matcher: matcher, requestBuilder: value)
    }
    
    public func key(_ value: AnyHashable) -> Self {
        Self(key, matcher: matcher, requestBuilder: requestBuilder)
    }
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        StringParserDataTask(request: inputValue, encoding: .utf8, sessionKey: key)
            .publisher()
            .tryMap { try matcher.extract($0) }
            .map { urls in
                urls.compactMap {
                    do {
                        return try requestBuilder.make($0.absoluteString, refer: BaseURL(url: inputValue.url).domainURL())
                    }   catch   {
                        logger.error("download url make failed \(error)")
                        return nil
                    }
                }
            }
            .eraseToAnyPublisher()
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
    
    @inlinable
    public func sessionKey(_ value: AnyHashable) -> Self {
       key(value)
    }
}

public struct CDLinks: SessionableCondom {
    public typealias Input = URLRequest
    public typealias Output = [URLRequest]
    
    public var key: AnyHashable
    
    public init(_ key: AnyHashable = "default") {
        self.key = key
    }
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        DownloadLinks(key, matcher: CDPhpMatch(host: BaseURL(url: inputValue.url).domainURL()),
                      requestBuilder: PHPFileDownload(url: "", refer: ""))
            .publisher(for: inputValue)
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        CDLinks(value)
    }
}

struct BaseURL {
    let url: URL?
    
    func domainURL() -> String {
        guard let path = url, let scheme = path.scheme, let host = path.host else {
            return ""
        }
        
        return "\(scheme)://\(host)"
    }
    
    func replaceHost(_ otherURL: URL) -> URL? {
        guard let url = url else {
#if DEBUG
            logger.error("replace url failed. nil url")
#endif
            return nil
        }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
#if DEBUG
            logger.error("replace url failed. use origin \(url)")
#endif
            return url
        }
        
        guard let next = components.url(relativeTo: otherURL) else {
#if DEBUG
            logger.error("replace url failed. use origin \(url)")
#endif
            return url
        }
        
        return next
    }
}
