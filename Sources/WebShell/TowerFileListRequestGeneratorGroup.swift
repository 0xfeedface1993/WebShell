//
//  File.swift
//  
//
//  Created by john on 2023/9/6.
//

import Foundation

#if COMBINE_LINUX && canImport(CombineX)
import CombineX
#else
import Combine
#endif

#if canImport(Durex)
import Durex
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct TowerFileListRequestGeneratorGroup: SessionableCondom {
    public typealias Input = URLRequest
    public typealias Output = URLRequest
    
    public let fileid: String
    public let action: String
    public var key: AnyHashable
    
    public init(_ fileid: String, action: String, key: AnyHashable = "default") {
        self.fileid = fileid
        self.action = action
        self.key = key
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        .init(fileid, action: action, key: value)
    }
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        Future {
            try await AsyncTowerFileListRequestGeneratorGroup(fileid, action: action, configures: .shared, key: key).execute(for: URLRequestBuilder(inputValue)).build()
        }
        .eraseToAnyPublisher()
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
}

public struct AsyncTowerFileListRequestGeneratorGroup: SessionableDirtyware {
    public typealias Input = URLRequestBuilder
    public typealias Output = URLRequestBuilder
    
    public let fileid: String
    public let action: String
    public var key: AnyHashable
    public let configures: AsyncURLSessionConfiguration
    
    public init(_ fileid: String, action: String, configures: AsyncURLSessionConfiguration, key: AnyHashable = "default") {
        self.fileid = fileid
        self.action = action
        self.key = key
        self.configures = configures
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        .init(fileid, action: action, configures: configures, key: value)
    }
    
    public func execute(for inputValue: URLRequestBuilder) async throws -> URLRequestBuilder {
        try await AsyncTowerCookieUpdate(fileid: fileid, key: key, configures: configures)
            .join(AsyncTowerFileListRequestGenerator(fileid, action: action, url: inputValue.url ?? "", key: key))
            .execute(for: inputValue)
    }
}
