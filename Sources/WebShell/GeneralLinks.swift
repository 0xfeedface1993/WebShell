//
//  File.swift
//  
//
//  Created by john on 2023/9/7.
//

import Foundation

#if canImport(Durex)
import Durex
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// 查找http下载链接，用双扩号引起来的链接"https://xxxxx"，生成下载请求，可能会有多个下载请求
public struct GeneralLinks: SessionableDirtyware {
    public typealias Input = URLRequestBuilder
    public typealias Output = [URLRequestBuilder]
    
    public let key: SessionKey
    public var configures: AsyncURLSessionConfiguration
    
    public init(_ configures: AsyncURLSessionConfiguration, key: SessionKey = .host("default")) {
        self.key = key
        self.configures = configures
    }
    
    public func execute(for inputValue: URLRequestBuilder) async throws -> [URLRequestBuilder] {
        let string = try await StringParserDataTask(request: inputValue, encoding: .utf8, sessionKey: key, configures: configures).asyncValue()
        let urls = try FileGeneralLinkMatch(html: string).extract()
        let refer = inputValue.url ?? ""
        let next = urls.compactMap {
            GeneralFileDownload(url: $0.absoluteString, refer: refer).make()
        }
        shellLogger.info("find download links \(next)")
        return next
    }
    
    public func sessionKey(_ value: SessionKey) -> Self {
        .init(configures, key: value)
    }
}
