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

#if COMBINE_LINUX && canImport(CombineX)
import CombineX
#else
import Combine
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

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

public struct AsyncCDLinks: SessionableDirtyware {
    public typealias Input = URLRequestBuilder
    public typealias Output = [URLRequestBuilder]
    
    public var key: AnyHashable
    public var configures: AsyncURLSessionConfiguration
    
    public init(_ configures: AsyncURLSessionConfiguration, key: AnyHashable = "default") {
        self.key = key
        self.configures = configures
    }
    
    public func execute(for inputValue: URLRequestBuilder) async throws -> [URLRequestBuilder] {
        let domainURL = BaseURL(url: URL(string: inputValue.url ?? "")).domainURL()
        let matcher = CDPhpMatch(host: domainURL)
        let builder = PHPFileDownload(url: "", refer: "")
        return try await AsyncDownloadLinks(key, matcher: matcher, requestBuilder: builder, configures: configures).execute(for: inputValue)
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        .init(configures, key: value)
    }
}
