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
        Future {
            try await AsyncDownloadLinks(key, matcher: matcher, requestBuilder: requestBuilder, configures: .shared)
                .execute(for: .init(inputValue))
                .compactMap({ try? $0.build() })
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

public struct AsyncDownloadLinks<Matcher: ContentMatch, RequestBuilder: DownloadRequestBuilder>: SessionableDirtyware {
    public typealias Input = URLRequestBuilder
    public typealias Output = [URLRequestBuilder]
    
    public var key: AnyHashable
    public let matcher: Matcher
    public let requestBuilder: RequestBuilder
    public var configures: AsyncURLSessionConfiguration
    
    public init(_ key: AnyHashable = "default", matcher: Matcher, requestBuilder: RequestBuilder, configures: AsyncURLSessionConfiguration) {
        self.key = key
        self.matcher = matcher
        self.requestBuilder = requestBuilder
        self.configures = configures
    }
    
    public func matcher<T: ContentMatch>(_ value: T) -> DownloadLinks<T, RequestBuilder> {
        DownloadLinks<T, RequestBuilder>(key, matcher: value, requestBuilder: requestBuilder)
    }
    
    public func builder<T: DownloadRequestBuilder>(_ value: T) -> DownloadLinks<Matcher, T> {
        DownloadLinks<Matcher, T>(key, matcher: matcher, requestBuilder: value)
    }
    
    public func key(_ value: AnyHashable) -> Self {
        Self(key, matcher: matcher, requestBuilder: requestBuilder, configures: configures)
    }
    
    public func execute(for inputValue: URLRequestBuilder) async throws -> [URLRequestBuilder] {
        let string = try await AsyncStringParserDataTask(request: inputValue, encoding: .utf8, sessionKey: key, configures: configures).asyncValue()
        let urls = try matcher.extract(string)
        let domainURL = BaseURL(url: URL(string: inputValue.url ?? "")).domainURL()
        let next = urls.compactMap {
            requestBuilder.make($0.absoluteString, refer: domainURL)
        }
        return next
    }
    
    @inlinable
    public func sessionKey(_ value: AnyHashable) -> Self {
       key(value)
    }
}
