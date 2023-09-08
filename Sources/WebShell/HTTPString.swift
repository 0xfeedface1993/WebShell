//
//  File.swift
//  
//
//  Created by john on 2023/9/8.
//

import Foundation

#if canImport(Durex)
import Durex
#endif

public struct HTTPString: SessionableDirtyware {
    public typealias Input = String
    public typealias Output = String
    
    public var key: AnyHashable
    public let configures: Durex.AsyncURLSessionConfiguration
    
    public init(_ configures: Durex.AsyncURLSessionConfiguration, key: AnyHashable = "default") {
        self.key = key
        self.configures = configures
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        .init(configures, key: value)
    }
    
    public func execute(for inputValue: String) async throws -> String {
        if inputValue.hasPrefix("http") {
            return inputValue
        }
        return "http://\(inputValue)"
    }
}
