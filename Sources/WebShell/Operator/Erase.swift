//
//  File.swift
//  WebShell
//
//  Created by york on 2025/9/5.
//

import Foundation
import Durex

public struct Erase<T: ContextValue>: Dirtyware {
    public typealias Input = KeyStore
    public typealias Output = T
    
    public let key: KeyStore.Key
    
    public init(_ key: KeyStore.Key = .output, to type: T.Type) {
        self.key = key
    }
    
    @inlinable
    public func execute(for inputValue: KeyStore) async throws -> T {
        try await inputValue.take(forKey: key)
    }
}

public struct JustValue<T: ContextValue>: Dirtyware{
    public typealias Output = KeyStore
    public typealias Input = T

    public init() {
        
    }
    
    public func execute(for inputValue: Input) async throws -> Output {
        KeyStore().assign(inputValue, forKey: .output)
    }
}

extension Dirtyware {
    @inlinable
    public func erase<T: ContextValue>(_ key: KeyStore.Key = .output, to type: T.Type) -> AnyDirtyware<Input, T> where Output == KeyStore {
        self.join(Erase(key, to: type))
    }
    
    @inlinable
    public func store(at key: KeyStore.Key = .output) -> AnyDirtyware<Input, KeyStore> {
        self.join(JustValue())
    }
}
