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
    
    public var key: AnyHashable
    public var configures: Durex.AsyncURLSessionConfiguration
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        .init(key: value, configures: configures)
    }
    
    public func execute(for inputValue: URLRequestBuilder) async throws -> URLRequestBuilder {
        try await AsyncSession(configures)
            .context(key)
            .requestBySetCookies(with: inputValue)
    }
}
