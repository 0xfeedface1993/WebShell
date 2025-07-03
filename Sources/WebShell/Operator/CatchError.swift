//
//  File.swift
//  WebShell
//
//  Created by york on 2025/7/3.
//

import Foundation
import Durex

public struct CatchError<T: Dirtyware>: Dirtyware {
    public typealias Input = T.Input
    public typealias Output = T.Output
    
    public let block: @Sendable (Error) async throws -> Void
    public let task: T
    
    public init(_ task: T, block: @Sendable @escaping (Error) async throws -> Void) {
        self.block = block
        self.task = task
    }

    public func execute(for inputValue: Input) async throws -> Output {
        let failed: Error
        do {
            return try await task.execute(for: inputValue)
        } catch {
            shellLogger.error("execute failed, error \(error)")
            try await block(error)
            failed = error
        }
        throw failed
    }
}

extension Dirtyware {
    @inlinable
    public func catchError(_ action: @Sendable @escaping (Error) async throws -> Void) -> CatchError<Self> {
        CatchError(self, block: action)
    }
}

public struct OnError<T: Dirtyware>: Dirtyware where T.Input == KeyStore {
    public typealias Input = T.Input
    public typealias Output = T.Output
    
    public let block: @Sendable (Error) async throws -> Void
    public let task: T
    
    public init(_ task: T, block: @Sendable @escaping (Error) async throws -> Void) {
        self.block = block
        self.task = task
    }

    public func execute(for inputValue: Input) async throws -> Output {
        let failed: Error
        do {
            return try await task.execute(for: inputValue)
        } catch {
            shellLogger.error("execute failed, error \(error)")
            try await block(error)
            failed = error
        }
        throw failed
    }
}

public struct FlatMapError<T: Dirtyware, V: Dirtyware>: Dirtyware where T.Input == KeyStore, T.Input == V.Input, T.Output == V.Output {
    public typealias Input = T.Input
    public typealias Output = T.Output
    
    public let block: @Sendable (Error, T.Input) async throws -> V
    public let task: T
    
    public init(_ task: T, block: @Sendable @escaping (Error, Input) async throws -> V) {
        self.block = block
        self.task = task
    }

    public func execute(for inputValue: Input) async throws -> Output {
        do {
            return try await task.execute(for: inputValue)
        } catch {
            shellLogger.error("execute failed, error \(error)")
            return try await block(error, inputValue).execute(for: inputValue)
        }
    }
}

extension Dirtyware {
    @inlinable
    public func ifError<T: Dirtyware>(_ action: @Sendable @escaping (Error, Self.Input) async throws -> T) -> FlatMapError<Self, T> where Self.Input == T.Input, Self.Output == T.Output {
        FlatMapError(self, block: action)
    }
}
