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

public struct TowerGroup: SessionableCondom {
    public typealias Input = String
    public typealias Output = URLRequest
    
    public let action: String
    public var key: AnyHashable
    
    public init(_ action: String, key: AnyHashable = "default") {
        self.action = action
        self.key = key
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        .init(action, key: value)
    }
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        Future {
            try await AsyncTowerGroup(action, configures: .shared, key: key).execute(for: inputValue).build()
        }
        .eraseToAnyPublisher()
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
}

public struct AsyncTowerGroup: SessionableDirtyware {
    public typealias Input = String
    public typealias Output = URLRequestBuilder
    
    public let action: String
    public var key: AnyHashable
    public let configures: Durex.AsyncURLSessionConfiguration
    
    public init(_ action: String, configures: Durex.AsyncURLSessionConfiguration, key: AnyHashable = "default") {
        self.action = action
        self.key = key
        self.configures = configures
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        .init(action, configures: configures, key: value)
    }
    
    private func fileid(_ string: String) throws -> String {
        try FileIDMatch.default.extract(string)
    }
    
    public func execute(for inputValue: String) async throws -> URLRequestBuilder {
        let fileid = try fileid(inputValue)
        return try await AsyncTowerJSPage(configures, key: key)
            .join(AsyncTowerFileListRequestGeneratorGroup(fileid, action: action, configures: configures, key: key))
            .execute(for: inputValue)
    }
}
