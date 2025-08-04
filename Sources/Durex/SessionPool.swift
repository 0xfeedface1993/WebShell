//
//  File.swift
//  
//
//  Created by john on 2023/9/5.
//

import Foundation
import AsyncAlgorithms
import AsyncBroadcaster

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
    enum SeesionWrapped {
        case new(AsyncCustomURLSession)
        case exists(AsyncCustomURLSession)
    }
    
    private var cache = [Sessions: any AsyncCustomURLSession]()
    
    @usableFromInline
    func set<Context>(_ context: Context, for key: Sessions) where Context: AsyncCustomURLSession {
        cache[key] = context
    }
    
    @usableFromInline
    func remove(_ key: Sessions) {
        cache.removeValue(forKey: key)
        logger.info("remove session context for \("\(key)")")
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
    
    func createIfNotExists(key: Sessions, configurations: AsyncURLSessionConfiguration) -> SeesionWrapped {
        if let value = context(forKey: key) {
            return .exists(value)
        }
        let session = configurations.newsSession()
        set(session, for: key)
        return .new(session)
    }
}

actor AsyncTaskPool {
    typealias TaskValue = Task<Void, Never>
    private var tasks = [Sessions: (work: TaskValue, id: UUID)]()
    
    @usableFromInline
    func set<Context>(_ context: Context, subject: ChannelSubject<AsyncUpdateNews>, for key: Sessions) where Context: AsyncCustomURLSession {
        if let bingo = tasks.first(where: { $0.value.id == context.id }) {
            logger.info("pool has observer for session [\("\(bingo.key)")] uuid [\(bingo.value.id)], try add duplicate observation with \("\(key)"), pass...")
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
    
    func task<S: AsyncSequence>(_ updates: sending S, subject: ChannelSubject<AsyncUpdateNews>, forKey key: Sessions) -> TaskValue where S.Element == AsyncUpdateNews, S: Sendable {
        return TaskValue(operation: {
            logger.info("observer session \("\(key)")")
            defer {
                logger.info("finished observer session \("\(key)")")
            }
            do {
                for try await news in updates {
                    // logger.info("send news [\(news)] to [\(key)]")
                    print("send news [\(news)] to [\(key)]")
                    await subject.send(news)
                }
            } catch {
                await subject.send(.init(value: .error(.init(error: error, identifier: 500)), tag: .int64(0)))
            }
        })
    }
    
    func removeTask(forKey key: Sessions) {
        if let oldTask = tasks[key]?.work, !oldTask.isCancelled {
            oldTask.cancel()
            logger.info("remove task observer for session \("\(key)")")
        }
    }
}

struct ResoucesPool {
    let sessions = AsyncSessionPool()
    let tasks = AsyncTaskPool()
    let subject = ChannelSubject<AsyncUpdateNews>()
}

public struct AsyncSession: Sendable {
    public let configures: AsyncURLSessionConfiguration
    
    public init(_ configures: AsyncURLSessionConfiguration) {
        self.configures = configures
    }
    
    public func state(for key: SessionKey) async throws -> AsyncCustomURLSession {
        let sessionKey = Sessions(key)
        return try await configures.resourcesPool.sessions.take(forKey: sessionKey)
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
    
    public func remove(by key: SessionKey) async {
        let sessionKey = Sessions(key)
        await configures.resourcesPool.sessions.remove(sessionKey)
    }
    
    public func context(_ key: SessionKey) async throws -> any AsyncCustomURLSession {
        let sessionKey = Sessions(key)
        do {
            let context = try await configures.resourcesPool.sessions.createIfNotExists(key: sessionKey, configurations: configures)
            switch context {
            case .new(let session):
                await configures
                    .resourcesPool
                    .tasks
                    .set(session, subject: configures.resourcesPool.subject, for: sessionKey)
                logger.info("create session \("\(context)") for \("\(sessionKey)")")
                return session
            case .exists(let session):
                logger.info("got session \("\(context)") for \("\(sessionKey)")")
                return session
            }
        } catch {
            logger.error("take session for \("\(sessionKey)") failed, \(error)")
            logger.info("use default session \("\(configures.defaultSession)")")
            return configures.defaultSession
        }
    }
    
    public func news() -> AsyncBroadcaster<AsyncUpdateNews> {
        configures.resourcesPool.subject.subscribe()
    }
}
