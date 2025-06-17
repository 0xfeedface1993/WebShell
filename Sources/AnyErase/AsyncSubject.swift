//
//  File.swift
//  WebShell
//
//  Created by sonoma on 11/17/24.
//

import Foundation

@globalActor
actor AsyncSubjectActor {
    static let shared = AsyncSubjectActor()
}

fileprivate actor AsyncSubjectHolder<T: Sendable> {
    public typealias Subject = AsyncThrowingStream<T, Error>
    private var continuations = [UUID: Subject.Continuation]()
    fileprivate var recentValue: T?
    
    deinit {
        let cached = continuations
        continuations.removeAll()
        for (_, continuation) in cached {
            continuation.finish()
        }
    }
    
    public func send(_ value: T) {
        recentValue = value
        for (_, continuation) in continuations {
            continuation.yield(value)
        }
    }
    
    public func completion(_ error: Error?) {
        recentValue = nil
        for (_, continuation) in continuations {
            if let error {
                continuation.finish(throwing: error)
            } else {
                continuation.finish()
            }
        }
        continuations.removeAll()
    }
    
    public func subscribe() -> (Subject, UUID) {
        let uuid = UUID()
        return (Subject { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }
            
            Task { @concurrent in
                await self.subscribe(continuation, uuid: uuid)
            }
        }, uuid)
    }
    
    fileprivate func subscribe(_ continuation: Subject.Continuation, uuid: UUID) {
        continuation.onTermination = { [weak self] finished in
            Task {
                await self?.drop(uuid)
            }
        }
        continuations[uuid] = continuation
        logger.trace("add continuation for \(uuid), total \(self.continuations.count) subscribers")
        if let recentValue {
            continuation.yield(recentValue)
        }
    }
    
    fileprivate func drop(_ id: UUID) {
        logger.trace("remove continuation for \(id), total \(self.continuations.count) subscribers")
        continuations.removeValue(forKey: id)
    }
    
    public func subscribersCount() -> Int {
        continuations.count
    }
}

public struct AsyncSubject<T: Sendable>: Sendable {
    public typealias Subject = AsyncThrowingStream<T, Error>
    private let holder = AsyncSubjectHolder<T>()
    
    public var currentValue: T? {
        get async {
            await holder.recentValue
        }
    }
    
    public init() {
        
    }
    
    public func send(_ value: T) {
        Task { @concurrent in
            await holder.send(value)
        }
    }
    
    public func completion(_ error: Error?) {
        Task { @concurrent in
            await holder.completion(error)
        }
    }
    
    public func subscribe() -> (Subject, UUID) {
        let uuid = UUID()
        return (Subject { continuation in
            Task { @concurrent in
                await holder.subscribe(continuation, uuid: uuid)
            }
        }, uuid)
    }
    
    public func subscribersCount() async -> Int {
        await holder.subscribersCount()
    }
}
