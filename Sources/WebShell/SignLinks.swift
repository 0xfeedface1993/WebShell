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

public struct SignLinks: SessionableDirtyware {
    public typealias Input = URLRequestBuilder
    public typealias Output = [URLRequestBuilder]
    
    public var key: AnyHashable
    public var configures: AsyncURLSessionConfiguration
    
    public init(_ configures: AsyncURLSessionConfiguration, key: AnyHashable = "default") {
        self.key = key
        self.configures = configures
    }
    
    public func execute(for inputValue: URLRequestBuilder) async throws -> [URLRequestBuilder] {
        guard let inputRawURL = inputValue.url, let inputURL = URL(string: inputRawURL) else {
            shellLogger.error("inputValue url is nil. \(inputValue)")
            return []
        }
        let string = try await StringParserDataTask(request: inputValue, encoding: .utf8, sessionKey: key, configures: configures).asyncValue()
        let urls = try FileGeneralLinkMatch(html: string).extract()
        let refer = inputURL.removeURLPath().absoluteString
        let next = urls.compactMap {
            do {
                return try SignPHPFileDownload(url: $0.absoluteString, refer: refer).make()
            }   catch   {
                shellLogger.error("download url make failed \(error)")
                return nil
            }
            
        }
        shellLogger.error("find download links \(next)")
        return next
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        .init(configures, key: key)
    }
}
