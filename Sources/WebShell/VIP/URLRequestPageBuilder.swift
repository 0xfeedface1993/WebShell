//
//  File.swift
//  WebShell
//
//  Created by york on 2025/6/25.
//

import Foundation
import Durex

public struct URLRequestPageBuilder: Dirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public var assignKey: KeyStore.Key?
    public let build: @Sendable (Input) async throws -> [URLRequestBuilder]
    
    public init(_ assignKey: KeyStore.Key? = nil, build: @Sendable @escaping (Input) async throws -> [URLRequestBuilder]) {
        self.assignKey = assignKey
        self.build = build
    }
    
    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        let request = try await build(inputValue)
        if let assignKey {
            inputValue.assign(request, forKey: assignKey)
        }
        return inputValue.assign(request, forKey: .output)
    }
}
