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

public struct SignPHPFileDownload: DownloadRequestBuilder {
    let url: String
    let refer: String

    func make() throws -> URLRequestBuilder {
        make(url, refer: refer)
    }

    public func make(_ url: String, refer: String) -> URLRequestBuilder {
        URLRequestBuilder(url)
            .method(.get)
            .add(value: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forKey: "accept")
            .add(value: "en-US,en;q=0.9", forKey: "accept-language")
            .add(value: userAgent, forKey: "user-agent")
            .add(value: refer, forKey: "referer")
            .add(value: "keep-alive", forKey: "Connection")
    }
}


public struct PHPFileDownload: DownloadRequestBuilder {
    let url: String
    let refer: String
    
    func make() -> URLRequestBuilder {
        make(url, refer: refer)
    }
    
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

/// 查找`dl.php`的普通限速下载链接，生成下载请求，可能会有多个下载请求
public struct PHPLinks: SessionableDirtyware {
    public typealias Input = URLRequestBuilder
    public typealias Output = [URLRequestBuilder]
    
    public var key: AnyHashable
    public var configures: AsyncURLSessionConfiguration
    
    public init(_ configures: AsyncURLSessionConfiguration, key: AnyHashable = "default") {
        self.key = key
        self.configures = configures
    }
    
    public func execute(for inputValue: URLRequestBuilder) async throws -> [URLRequestBuilder] {
        let matcher = DLPhpMatch(url: "")
        let builder = PHPFileDownload(url: "", refer: "")
        return try await DownloadLinks(key, matcher: matcher, requestBuilder: builder, configures: configures).execute(for: inputValue)
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        .init(configures, key: value)
    }
}


