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

public struct ActionDownPage: Dirtyware {
    public typealias Input = String
    public typealias Output = URLRequestBuilder
    
    public var key: AnyHashable
    
    public init(_ key: AnyHashable = "default") {
        self.key = key
    }
    
    public func execute(for inputValue: String) async throws -> URLRequestBuilder {
        try await FileListURLRequestGenerator(.lastPath, action: "load_down_addr5")
            .execute(for: inputValue)
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        .init(value)
    }
}
