//
//  File.swift
//  
//
//  Created by Peter on 2023/2/22.
//

import Foundation
import Combine
#if canImport(AnyErase)
import AnyErase
#endif

public struct SessionError: Error, LocalizedError {
    let pool: SessionPool?
    let context: (any SessionContext)?
    
    public var errorDescription: String? {
        if let _ = pool, let _ = context {
            return ">>> No Session Error."
        }
        
        if let context = context {
            return ">>> Make session failed only context \(context) exist."
        }
        
        if let pool = pool {
            return ">>> Make session failed only pool \(pool) exist."
        }
        
        return ">>> No Session Error."
    }
}

public enum SessionKeyError: Error {
    case noValidKey(AnyHashable)
}

//public protocol SessionContext {
//    func session() -> CustomURLSession
//}

public typealias SessionContext = CustomURLSession

//extension URLSession: SessionContext {
//    @inlinable
//    public func session() -> CustomURLSession {
//        self
//    }
//}

@usableFromInline
enum Sessions: Hashable {
    case `default`
    case key(any Hashable)
    
    fileprivate static var cache = [Sessions: SessionPoolState]()
    
    @usableFromInline
    static func == (lhs: Sessions, rhs: Sessions) -> Bool {
        lhs.hashValue == rhs.hashValue
    }
    
    @usableFromInline
    func hash(into hasher: inout Hasher) {
        switch self {
        case .default:
            hasher.combine(self)
        case .key(let hashable):
            hasher.combine(hashable)
        }
    }
    
    init(_ hash: any Hashable) {
        self = .key(hash)
    }
    
    fileprivate func store(_ context: SessionContext) -> SessionContext {
        let value = Sessions.cache[self] ?? SessionPoolState(context)
        value.context = context
        Sessions.cache[self] = value
        return context
    }
    
    fileprivate func clear() {
        Sessions.cache.removeValue(forKey: self)
    }
    
    func take() throws -> SessionPoolState {
        switch self {
        case .default:
            throw DurexError.nilSession
        case .key(_):
            guard let value = Sessions.cache[self] else {
                throw DurexError.nilSession
            }
            return value
        }
    }
}

public final class SessionPoolState {
    @Published var context: SessionContext?
    
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
            .receive(on: DispatchQueue.main)
            .tryMap {
                try $0.take()
            }
            .eraseToAnyPublisher()
    }
    
    public static func register(_ pool: SessionContext, forKey key: any Hashable) -> AnyPublisher<SessionContext, Never> {
        Just(Sessions(key))
            .receive(on: DispatchQueue.main)
            .map {
                $0.store(pool)
            }
            .eraseToAnyPublisher()
    }
    
    public static func remove(by key: any Hashable) -> AnyPublisher<Void, Never> {
        Just(Sessions(key))
            .receive(on: DispatchQueue.main)
            .map {
                $0.clear()
            }
            .eraseToAnyPublisher()
    }
    
    public static func context(_ key: any Hashable) -> AnyPublisher<SessionContext, Error> {
        Just(Sessions(key))
            .receive(on: DispatchQueue.main)
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
                print(">>> context session \($0) for key \(key)")
            })
            .setFailureType(to: Error.self)
#endif
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

public struct PoolMaker {
    let context: (any SessionContext)?
    let key: (any Hashable)?
    
    public init(_ context: (any SessionContext)?, key: (any Hashable)? = nil) {
        self.context = context
        self.key = key
    }
    
    func key(_ value: any Hashable) -> Self {
        PoolMaker(context, key: value)
    }
    
    func context(_ value: any SessionContext) -> Self {
        PoolMaker(value, key: key)
    }
    
    func _store(_ value: (any SessionContext)?, forKey: (any Hashable)?) {
        guard let context = value, let key = forKey else {
            return
        }
        _ = Sessions(key).store(context)
    }
    
    public func store() -> AnyPublisher<SessionContext, Error> {
        guard let context = context, let key = key else {
            return Fail(error: SessionError(pool: nil, context: context))
                .eraseToAnyPublisher()
        }
        return AnyValue((context, key))
            .receive(on: DispatchQueue.main)
            .follow(_store(_:forKey:))
            .map(\.0)
            .eraseToAnyPublisher()
    }
}
