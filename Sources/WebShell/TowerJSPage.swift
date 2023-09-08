//
//  File.swift
//  
//
//  Created by john on 2023/8/5.
//

import Foundation
import Durex

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct TowerJSPage: SessionableDirtyware {
    public typealias Input = String
    
    public typealias Output = URLRequestBuilder
    
    public let key: AnyHashable
    public let configures: AsyncURLSessionConfiguration
    
    public func execute(for inputValue: String) async throws -> URLRequestBuilder {
        let request = try pageRequest(inputValue).make()
        let string = try await StringParserDataTask(request: request, encoding: .utf8, sessionKey: key, configures: configures).asyncValue()
        let url = try url(string, url: inputValue)
        return url
    }
    
    private func fileid(_ string: String) throws -> String {
        try FileIDMatch.default.extract(string)
    }
    
    private func pageRequest(_ string: String) throws -> TowerFilePageRequest {
        let fileid = try fileid(string)
        let (host, scheme) = try string.baseComponents()
        return TowerFilePageRequest(fileid: fileid, scheme: scheme, host: host)
    }
    
    private func url(_ content: String, url: String) throws -> URLRequestBuilder {
        let relatePath = try TowerJSMatch().extract(content)
        let fileid = try fileid(url)
        let (host, scheme) = try url.baseComponents()
        return TowerJSPageRequest(fileid: fileid, scheme: scheme, host: host, path: relatePath).make()
    }
    
    public init(_ configures: AsyncURLSessionConfiguration, key: AnyHashable = "default") {
        self.key = key
        self.configures = configures
    }
    
    public func sessionKey(_ value: AnyHashable) -> TowerJSPage {
        .init(configures, key: value)
    }
}

public struct TowerFilePageRequest {
    let fileid: String
    let scheme: String
    let host: String
    
    func make() -> URLRequestBuilder {
        let http = "\(scheme)://\(host)"
        let url = "\(http)/file-\(fileid).html"
        return URLRequestBuilder(url)
            .method(.get)
            .add(value: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forKey: "accept")
            .add(value: userAgent, forKey: "user-agent")
            .add(value: "en-US,en;q=0.9", forKey: "accept-language")
    }
}

public struct TowerJSPageRequest {
    let fileid: String
    let scheme: String
    let host: String
    let path: String
    
    func make() -> URLRequestBuilder {
        let http = "\(scheme)://\(host)"
        let url = "\(http)\(path)"
        let referURL = "\(http)/file-\(fileid).html"
        return URLRequestBuilder(url)
            .method(.get)
            .add(value: "*/*", forKey: "accept")
            .add(value: userAgent, forKey: "user-agent")
            .add(value: "en-US,en;q=0.9", forKey: "accept-language")
            .add(value: referURL, forKey: "referer")
    }
}

public struct TowerJSMatch {
    let pattern = "src=\"([^\"]+)\"\\>"
    
    public func extract(_ text: String) throws -> String {
        try FileIDMatch(pattern).extract(text)
    }
}
