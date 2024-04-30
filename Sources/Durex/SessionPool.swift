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

import AsyncExtensions

actor AsyncSessionPool {
    private var cache = [Sessions: any AsyncCustomURLSession]()
    
    @usableFromInline
    func set<Context>(_ context: Context, for key: Sessions) where Context: AsyncCustomURLSession {
        cache[key] = context
    }
    
    @usableFromInline
    func remove(_ key: Sessions) {
        cache.removeValue(forKey: key)
        logger.info("remove session context for \(key)")
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
    
//    /// 当前下载池中所有session
//    func sessions() -> [any AsyncCustomURLSession] {
//        cache.map(\.value)
//    }
}

actor AsyncTaskPool {
    typealias TaskValue = Task<Void, Never>
    private var tasks = [Sessions: (work: TaskValue, id: UUID)]()
    
    @usableFromInline
    func set<Context>(_ context: Context, subject: AsyncPassthroughSubject<AsyncUpdateNews>, for key: Sessions) where Context: AsyncCustomURLSession {
        if let bingo = tasks.first(where: { $0.value.id == context.id }) {
            logger.info("pool has observer for session [\(bingo.key)] uuid [\(bingo.value.id)], try add duplicate observation with \(key), pass...")
            return
        }
        let updates = context.downloadNews()
        removeTask(forKey: key)
        tasks[key] = (task(updates, subject: subject, forKey: key), context.id)
    }
    
    @usableFromInline
    func remove(_ key: Sessions) {
        removeTask(forKey: key)
    }
    
    @usableFromInline
    func task(forKey key: Sessions) -> TaskValue? {
        tasks[key]?.work
    }
    
    func task(_ updates: AnyAsyncSequence<AsyncUpdateNews>, subject: AsyncPassthroughSubject<AsyncUpdateNews>, forKey key: Sessions) -> TaskValue {
        TaskValue {
            logger.info("observer session \(key)")
            defer {
                logger.info("finished observer session \(key)")
            }
            do {
                for try await news in updates {
                    // logger.info("send news [\(news)] to [\(key)]")
                    print("send news [\(news)] to [\(key)]")
                    subject.send(news)
                }
            } catch {
                logger.info("catch error from observer session \(key), \(error)")
            }
        }
    }
    
    func removeTask(forKey key: Sessions) {
        if let oldTask = tasks[key]?.work, !oldTask.isCancelled {
            oldTask.cancel()
            logger.info("remove task observer for session \(key)")
        }
    }
}

struct ResoucesPool {
    let sessions = AsyncSessionPool()
    let tasks = AsyncTaskPool()
    let subject = AsyncPassthroughSubject<AsyncUpdateNews>()
}

public struct AsyncSession {
    public let configures: AsyncURLSessionConfiguration
    
    public init(_ configures: AsyncURLSessionConfiguration) {
        self.configures = configures
    }
    
    public func state<Key>(for key: Key) async throws -> AsyncCustomURLSession where Key: Hashable {
        let sessionKey = Sessions(key)
        return try await configures.resourcesPool.sessions.take(forKey: sessionKey)
    }
    
    public func register<Context, Key>(_ context: Context, forKey key: Key) async -> Context where Key: Hashable, Context: AsyncCustomURLSession {
        let sessionKey = Sessions(key)
        
        await configures
            .resourcesPool
            .sessions
            .set(context, for: sessionKey)
        
        await configures
            .resourcesPool
            .tasks
            .set(context, subject: configures.resourcesPool.subject, for: sessionKey)
        
        return context
    }
    
    func registerDefaultContext<Context>(_ context: Context) async -> Context where Context: AsyncCustomURLSession {
        let sessionKey = Sessions.default
        
        await configures
            .resourcesPool
            .sessions
            .set(context, for: sessionKey)
        
        await configures
            .resourcesPool
            .tasks
            .set(context, subject: configures.resourcesPool.subject, for: sessionKey)
        
        return context
    }
    
    public func remove<Key>(by key: Key) async where Key: Hashable {
        let sessionKey = Sessions(key)
        await configures.resourcesPool.sessions.remove(sessionKey)
    }
    
    public func context<Key>(_ key: Key) async throws -> any AsyncCustomURLSession where Key: Hashable {
        let sessionKey = Sessions(key)
        do {
            let context = try await configures.resourcesPool.sessions.take(forKey: sessionKey)
            logger.info("got session \(context) for \(sessionKey)")
            return context
        } catch {
            logger.error("take session for \(sessionKey) failed, \(error)")
            logger.info("use default session \(configures.defaultSession)")
            return configures.defaultSession
        }
    }
    
    public func news() -> AnyAsyncSequence<AsyncUpdateNews> {
        configures
            .resourcesPool
            .subject
            .eraseToAnyAsyncSequence()
    }
}
