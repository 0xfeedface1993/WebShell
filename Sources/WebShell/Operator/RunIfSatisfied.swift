//
//  File.swift
//  
//
//  Created by john on 2023/9/20.
//

import Foundation
import Durex

public struct RunIfKeyExists<T: Dirtyware<KeyStore, KeyStore>>: Dirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public let task: T
    public let key: KeyStore.Key
    
    public init(_ task: T, ifExists key: KeyStore.Key) {
        self.task = task
        self.key = key
    }
    
    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        let value: Any? = inputValue.value(forKey: key)
        if let value = value {
            shellLogger.info("got \(value) for \(key), execute task \(task)")
            return try await task.execute(for: inputValue)
        }
        shellLogger.info("value for \(key) not found, not execute task \(task)")
        return inputValue
    }
}

public struct RunIfSatisfied<T: Dirtyware>: Dirtyware where T.Output == KeyStore, T.Input == KeyStore {
    public typealias Input = T.Input
    public typealias Output = T.Output
    
    public let task: T
    public let block: (T.Input, T) async -> Bool
    
    public init(_ task: T, block: @escaping (T.Input, T) async -> Bool) {
        self.task = task
        self.block = block
    }
    
    public func execute(for inputValue: T.Input) async throws -> T.Output {
        if await block(inputValue, task) {
            shellLogger.info("permission granted, execute task \(task)")
            return try await task.execute(for: inputValue)
        }
        shellLogger.info("permission denied, not execute task \(task)")
        return inputValue
    }
}

extension Dirtyware {
    /// retry task if error throw
    public func `if`(exists key: KeyStore.Key) -> RunIfKeyExists<Self> where Self.Input == Self.Output {
        .init(self, ifExists: key)
    }
    
    /// execute task if condition block return true
    public func maybe(_ block: @escaping (Self.Input, Self) async -> Bool) -> RunIfSatisfied<Self> where Self.Input == Self.Output {
        .init(self, block: block)
    }
}
