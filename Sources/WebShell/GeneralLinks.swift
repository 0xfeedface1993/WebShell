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

#if COMBINE_LINUX && canImport(CombineX)
import CombineX
#else
import Combine
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// 查找http下载链接，用双扩号引起来的链接"https://xxxxx"，生成下载请求，可能会有多个下载请求
public struct GeneralLinks: SessionableCondom {
    public typealias Input = URLRequest
    public typealias Output = [URLRequest]
    
    public var key: AnyHashable
    
    public init(_ key: AnyHashable = "default") {
        self.key = key
    }
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        Future {
            try await AsyncGeneralLinks(.shared, key: key)
                .execute(for: .init(inputValue))
                .compactMap({ try? $0.build() })
        }
        .eraseToAnyPublisher()
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
    
    public func sessionKey(_ value: AnyHashable) -> GeneralLinks {
        GeneralLinks(value)
    }
}

public struct AsyncGeneralLinks: SessionableDirtyware {
    public typealias Input = URLRequestBuilder
    public typealias Output = [URLRequestBuilder]
    
    public var key: AnyHashable
    public var configures: AsyncURLSessionConfiguration
    
    public init(_ configures: AsyncURLSessionConfiguration, key: AnyHashable = "default") {
        self.key = key
        self.configures = configures
    }
    
    public func execute(for inputValue: URLRequestBuilder) async throws -> [URLRequestBuilder] {
        let string = try await AsyncStringParserDataTask(request: inputValue, encoding: .utf8, sessionKey: key, configures: configures).asyncValue()
        let urls = try FileGeneralLinkMatch(html: string).extract()
        let refer = inputValue.url ?? ""
        let next = urls.compactMap {
            GeneralFileDownload(url: $0.absoluteString, refer: refer).make()
        }
        shellLogger.info("find download links \(next)")
        return next
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        .init(configures, key: value)
    }
}
