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

public final class SessionPoolState {
    var context: SessionContext?
    
    init(_ context: SessionContext?) {
        self.context = context
    }
}

public enum SessionPool {
    //public static let state = SessionPoolState()
}

extension SessionPool {
    private static func state(for key: any Hashable) -> AnyPublisher<SessionPoolState, Error> {
        Just(Sessions(key))
            .receive(on: DispatchQueue.main.scheduler)
            .tryMap {
                try $0.take()
            }
            .eraseToAnyPublisher()
    }
    
    public static func register(_ pool: SessionContext, forKey key: any Hashable) -> AnyPublisher<SessionContext, Never> {
        Just(Sessions(key))
            .receive(on: DispatchQueue.main.scheduler)
            .map {
                $0.store(pool)
            }
            .eraseToAnyPublisher()
    }
    
    public static func remove(by key: any Hashable) -> AnyPublisher<Void, Never> {
        Just(Sessions(key))
            .receive(on: DispatchQueue.main.scheduler)
            .map {
                $0.clear()
            }
            .eraseToAnyPublisher()
    }
    
    public static func context(_ key: any Hashable) -> AnyPublisher<SessionContext, Error> {
        Just(Sessions(key))
            .receive(on: DispatchQueue.main.scheduler)
            .tryMap {
                try $0.take().context
            }
//#if DEBUG
//            .logError()
//#endif
            .replaceError(with: nil)
            .replaceNil(with: DownloadSession.shared())
#if DEBUG
            .follow({
                logger.info("context session \($0) for key \(key)")
            })
#endif
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
//    public static func justContext<T>(_ anyItem: T) -> AnyPublisher<SessionContext, Error> {
//        key(for: anyItem)
//            .flatMap(context(forKey:))
//            .catch({ error in
//#if DEBUG
//                print(">>> justContext session get failed. \(error)")
//                print(">>> justContext session replace to \(DownloadSession.shared())")
//#endif
//                return Just(DownloadSession.shared())
//                    .setFailureType(to: Error.self)
//            })
//            .eraseToAnyPublisher()
//    }
//
//    public static func context<T>(_ anyItem: T) -> AnyPublisher<SessionContext, Error> {
//        context(forKey: anyItem as? Hashable)
//    }
//
//    public static func key<T>(for anyItem: T) -> AnyPublisher<AnyHashable, Error> {
//        Just(SessionKeyFinder(anyItem))
//            .receive(on: DispatchQueue.main)
//            .tryMap { try $0.key() }
//            .eraseToAnyPublisher()
//    }
}

public actor AsyncSessionPool {
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
