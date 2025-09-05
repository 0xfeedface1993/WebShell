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

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif


public struct LinkRequestHeader: Equatable, Sendable {
    public enum Key: String, Sendable {
        case accept = "accept"
        case capAccept = "Accept"
        case acceptLanguage = "accept-language"
        case customUserAgent = "user-agent"
        case referer = "referer"
        case connection = "Connection"
        case priority = "Priority"
        case acceptEncoding = "Accept-Encoding"
        case origin = "Origin"
        case contentType = "Content-Type"
        case xXSRFToken = "X-XSRF-TOKEN"
        case xCSRFToken = "X-CSRF-TOKEN"
        case xRequestedWith = "X-Requested-With"
    }
    
    public let key: Key
    public let value: String
    
    public static let allAccept = LinkRequestHeader(key: .accept, value: "*/*")
    public static let allCapAccept = LinkRequestHeader(key: .capAccept, value: "*/*")
    public static let generalAccept = LinkRequestHeader(key: .accept, value: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
    public static let generalShortAccept = LinkRequestHeader(key: .accept, value: "text/html, application/xhtml+xml")
    public static let enUSAcceptLanguage = LinkRequestHeader(key: .acceptLanguage, value: "en-US,en;q=0.9")
    public static let customUserAgent = LinkRequestHeader(key: .customUserAgent, value: userAgent)
    public static let keepAliveConnection = LinkRequestHeader(key: .connection, value: "keep-alive")
    public static let priority = LinkRequestHeader(key: .priority, value: "u=3, i")
    public static let gzipAcceptEncoding = LinkRequestHeader(key: .acceptEncoding, value: "gzip, deflate, br, zstd")
    public static let urlencodedContentType = LinkRequestHeader(key: .contentType, value: "application/x-www-form-urlencoded; charset=UTF-8")
    public static let jsonContentType = LinkRequestHeader(key: .contentType, value: "application/json")
    public static let xmlHttpRequest = LinkRequestHeader(key: .xRequestedWith, value: "XMLHttpRequest")
    public static let zhHans = LinkRequestHeader(key: .acceptLanguage, value: "zh-CN,zh-Hans;q=0.9")
    public static let allImageAccept = LinkRequestHeader(key: .accept, value: "image/webp,image/avif,image/jxl,image/heic,image/heic-sequence,video/*;q=0.8,image/png,image/svg+xml,image/*;q=0.8,*/*;q=0.5")
}

extension URLRequestBuilder {
    @inlinable
    public func add(value: String?, forKey key: LinkRequestHeader.Key) -> URLRequestBuilder {
        if let value {
            return self.add(value: value, forKey: key.rawValue)
        }
        return self.deop(key: key.rawValue)
    }
    
    @inlinable
    public func add(_ header: LinkRequestHeader) -> URLRequestBuilder {
        return self.add(value: header.value, forKey: header.key.rawValue)
    }
}

public struct File116Download: DownloadRequestBuilder {
    public init() {}

    public func make(_ url: String, refer: String) -> URLRequestBuilder {
        URLRequestBuilder(url)
            .method(.get)
            .add(value: LinkRequestHeader.allCapAccept.value, forKey: LinkRequestHeader.allCapAccept.key.rawValue)
            .add(value: LinkRequestHeader.gzipAcceptEncoding.value, forKey: LinkRequestHeader.gzipAcceptEncoding.key.rawValue)
            .add(value: LinkRequestHeader.enUSAcceptLanguage.value, forKey: LinkRequestHeader.enUSAcceptLanguage.key.rawValue)
            .add(value: LinkRequestHeader.customUserAgent.value, forKey: LinkRequestHeader.customUserAgent.key.rawValue)
            .add(value: refer, forKey: LinkRequestHeader.Key.referer.rawValue)
            .add(value: LinkRequestHeader.keepAliveConnection.value, forKey: LinkRequestHeader.keepAliveConnection.key.rawValue)
            .add(value: LinkRequestHeader.priority.value, forKey: LinkRequestHeader.priority.key.rawValue)
    }
}

public struct SignPHPFileDownload: DownloadRequestBuilder {
//    let url: String
//    let refer: String

//    func make() -> URLRequestBuilder {
//        make(url, refer: refer)
//    }
    
    public init() {}

    public func make(_ url: String, refer: String) -> URLRequestBuilder {
        URLRequestBuilder(url)
            .method(.get)
            .add(value: LinkRequestHeader.generalAccept.value, forKey: LinkRequestHeader.generalAccept.key.rawValue)
            .add(value: "en-US,en;q=0.9", forKey: "accept-language")
            .add(value: userAgent, forKey: "user-agent")
            .add(value: refer, forKey: "referer")
            .add(value: "keep-alive", forKey: "Connection")
    }
}


public struct PHPFileDownload: DownloadRequestBuilder {
//    let url: String
//    let refer: String
    
//    func make() -> URLRequestBuilder {
//        make(url, refer: refer)
//    }
    
    public init() {}
    
    public func make(_ url: String, refer: String) -> URLRequestBuilder {
        URLRequestBuilder(url)
            .method(.get)
            .add(value: "1", forKey: "Upgrade-Insecure-Requests")
            .add(value: fullAccept, forKey: "Accept")
            .add(value: userAgent, forKey: "User-Agent")
            .add(value: refer, forKey: "Referer")
            .add(value: "zh-CN,zh-Hans;q=0.9", forKey: "Accept-Language")
            .add(value: "keep-alive", forKey: "Connection")
    }
}

public struct GeneralFileDownload {
    let url: String
    let refer: String
    
    func make() -> URLRequestBuilder {
        URLRequestBuilder(url)
            .method(.get)
            .add(value: fullAccept, forKey: "accept")
            .add(value: userAgent, forKey: "user-agent")
            .add(value: refer, forKey: "referer")
            .add(value: "zh-CN,zh-Hans;q=0.9", forKey: "accept-language")
            .add(value: "keep-alive", forKey: "Connection")
    }
}

public struct DLPhpMatch: ContentMatch {
    let url: String
    let pattern = "https?://[^\\s]+/dl\\w*\\.php\\?[^\"]+"
    
    func extract() throws -> [URL] {
        try extract(url)
    }
    
    public func extract(_ text: String) throws -> [URL] {
        try URLRegularExpressionMatch(string: text, pattern: pattern, template: Templates.dollar(0))
            .extract()
    }
}

public struct CDPhpMatch: ContentMatch {
    let host: String
    let pattern = "cd\\w*\\.php\\?[^\"]+"
    
    public func extract(_ url: String) throws -> [URL] {
        let results = try URLRegularExpressionMatch(string: url, pattern: pattern, template: Templates.dollar(0))
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

public struct FileGeneralLinkMatch: ContentMatch {
    let html: String
    let pattern = "\"(https?://[^\"]+)\""
    
    public init(html: String = "") {
        self.html = html
    }
    
    func extract() throws -> [URL] {
        try URLRegularExpressionMatch(string: html, pattern: pattern, template: Templates.dollar(1))
            .extract()
    }
    
    public func extract(_ text: String) throws -> [URL] {
        try URLRegularExpressionMatch(string: text, pattern: pattern, template: Templates.dollar(1))
            .extract()
    }
}

/// 查找`dl.php`的普通限速下载链接，生成下载请求，可能会有多个下载请求
public struct PHPLinks: SessionableDirtyware {
    public typealias Input = URLRequestBuilder
    public typealias Output = [URLRequestBuilder]
    
    public let key: SessionKey
    public var configures: AsyncURLSessionConfiguration
    
    public init(_ configures: AsyncURLSessionConfiguration, key: SessionKey = .host("default")) {
        self.key = key
        self.configures = configures
    }
    
    public func execute(for inputValue: URLRequestBuilder) async throws -> [URLRequestBuilder] {
        let matcher = DLPhpMatch(url: "")
        let builder = PHPFileDownload()
        return try await DownloadLinks(key, matcher: matcher, requestBuilder: builder, configures: configures).execute(for: inputValue)
    }
    
    public func sessionKey(_ value: SessionKey) -> Self {
        .init(configures, key: value)
    }
}

//public struct CombineReferLinks<Match: ContentMatch, LinkBuilder: DownloadRequestBuilder>: SessionableDirtyware {
//    public typealias Input = URLRequestBuilder
//    public typealias Output = [URLRequestBuilder]
//    
//    public let key: SessionKey
//    public var configures: AsyncURLSessionConfiguration
//    public let matcher: Match
//    public let linksBuilder: LinkBuilder
//    
//    public init(_ configures: AsyncURLSessionConfiguration, key: SessionKey = .host("default"), matcher: Match, linksBuilder: LinkBuilder) {
//        self.key = key
//        self.configures = configures
//        self.matcher = matcher
//        self.linksBuilder = linksBuilder
//    }
//    
//    public func execute(for inputValue: URLRequestBuilder) async throws -> [URLRequestBuilder] {
//        guard let inputRawURL = inputValue.url, let inputURL = URL(string: inputRawURL) else {
//            shellLogger.error("inputValue url is nil. \(inputValue)")
//            return []
//        }
//        let string = try await StringParserDataTask(request: inputValue, encoding: .utf8, sessionKey: key, configures: configures).asyncValue()
//        let urls = try matcher.extract(string)
//        let refer = inputURL.removeURLPath().absoluteString
//        let maker = linksBuilder
//        let next = urls.compactMap {
//            maker.make($0.absoluteString, refer: refer)
//        }
//        shellLogger.error("find download links \(next)")
//        return next
//    }
//    
//    public func sessionKey(_ value: SessionKey) -> Self {
//        .init(configures, key: value, matcher: matcher, linksBuilder: linksBuilder)
//    }
//}
