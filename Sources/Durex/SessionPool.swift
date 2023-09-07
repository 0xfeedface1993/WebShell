//
//  File.swift
//  
//
//  Created by john on 2023/9/5.
//

import Foundation

#if COMBINE_LINUX && canImport(CombineX)
import CombineX
import CXFoundation
#else
import Combine
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if canImport(AnyErase)
import AnyErase
#endif

actor AsyncSessionPool {
    private var cache = [Sessions: any AsyncCustomURLSession]()
    
    @usableFromInline
    func set<Context>(_ context: Context, for key: Sessions) where Context: AsyncCustomURLSession {
        cache[key] = context
    }
    
    @usableFromInline
    func remove(_ key: Sessions) {
        cache.removeValue(forKey: key)
    }
    
    @usableFromInline
    internal func context(forKey key: Sessions) -> (any AsyncCustomURLSession)? {
        cache[key]
    }
    
    func take(forKey key: Sessions) throws -> any AsyncCustomURLSession {
        switch key {
        case .default:
            throw DurexError.nilSession
        case .key(_):
            guard let value = context(forKey: key) else {
                throw DurexError.nilSession
            }
            return value
        }
    }
}

public struct AsyncSession {
    public let configures: AsyncURLSessionConfiguration
    
    public init(_ configures: AsyncURLSessionConfiguration) {
        self.configures = configures
    }
    
    public func state<Key>(for key: Key) async throws -> AsyncCustomURLSession where Key: Hashable {
        try await configures.sessionPool.take(forKey: Sessions(key))
    }
    
    public func register<Context, Key>(_ context: Context, forKey key: Key) async -> Context where Key: Hashable, Context: AsyncCustomURLSession {
        await configures.sessionPool.set(context, for: Sessions(key))
        return context
    }
    
    public func remove<Key>(by key: Key) async where Key: Hashable {
        await configures.sessionPool.remove(Sessions(key))
    }
    
    public func context<Key>(_ key: Key) async throws -> any AsyncCustomURLSession where Key: Hashable {
        do {
            let context = try await configures.sessionPool.take(forKey: Sessions(key))
            logger.info("got session \(context) for \(key)")
            return context
        } catch {
            logger.error("take session for \(key) failed, \(error)")
            logger.info("use default session \(configures.defaultSession)")
            return configures.defaultSession
        }
    }
}
