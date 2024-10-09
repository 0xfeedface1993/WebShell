//
//  File.swift
//  
//
//  Created by john on 2023/9/6.
//

import Foundation

#if canImport(Durex)
import Durex
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct CDLinks: SessionableDirtyware {
    public typealias Input = URLRequestBuilder
    public typealias Output = [URLRequestBuilder]
    
    public var key: SessionKey
    public var configures: AsyncURLSessionConfiguration
    
    public init(_ configures: AsyncURLSessionConfiguration, key: SessionKey = .host("default")) {
        self.key = key
        self.configures = configures
    }
    
    public func execute(for inputValue: URLRequestBuilder) async throws -> [URLRequestBuilder] {
        let domainURL = BaseURL(url: URL(string: inputValue.url ?? "")).domainURL()
        let matcher = CDPhpMatch(host: domainURL)
        let builder = PHPFileDownload()
        return try await DownloadLinks(key, matcher: matcher, requestBuilder: builder, configures: configures).execute(for: inputValue)
    }
    
    public func sessionKey(_ value: SessionKey) -> Self {
        .init(configures, key: value)
    }
}
