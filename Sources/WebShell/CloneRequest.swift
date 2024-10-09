//
//  File.swift
//  
//
//  Created by john on 2023/9/8.
//

import Foundation
import Durex

public struct CloneRequest: SessionableDirtyware {
    public typealias Input = URLRequestBuilder
    public typealias Output = URLRequestBuilder
    
    public var key: SessionKey
    public var configures: Durex.AsyncURLSessionConfiguration
    
    public init(_ configures: Durex.AsyncURLSessionConfiguration, key: SessionKey) {
        self.key = key
        self.configures = configures
    }
    
    public func sessionKey(_ value: SessionKey) -> Self {
        .init(configures, key: value)
    }
    
    public func execute(for inputValue: URLRequestBuilder) async throws -> URLRequestBuilder {
        try await AsyncSession(configures)
            .context(key)
            .requestBySetCookies(with: inputValue)
    }
}

public struct BatchCloneRequest: SessionableDirtyware {
    public typealias Input = [URLRequestBuilder]
    public typealias Output = [URLRequestBuilder]
    
    public var key: SessionKey
    public var configures: Durex.AsyncURLSessionConfiguration
    
    public init(_ configures: Durex.AsyncURLSessionConfiguration, key: SessionKey) {
        self.key = key
        self.configures = configures
    }
    
    public func sessionKey(_ value: SessionKey) -> Self {
        .init(configures, key: value)
    }
    
    public func execute(for inputValue: Input) async throws -> Output {
        let context = try await AsyncSession(configures).context(key)
        return inputValue.compactMap({
            do {
                return try context.requestBySetCookies(with: $0)
            } catch {
                shellLogger.error("remake request \($0.url ?? "Ooops!") failed, \(error)")
                return nil
            }
        })
    }
}
