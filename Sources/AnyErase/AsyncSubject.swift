//
//  File.swift
//  WebShell
//
//  Created by sonoma on 11/17/24.
//

import Foundation

@globalActor
actor AsyncSubjectActor {
    static var shared = AsyncSubjectActor()
}

fileprivate actor AsyncSubjectHolder<T: Sendable> {
    public typealias Subject = AsyncThrowingStream<T, Error>
    private var continuations = [UUID: Subject.Continuation]()
    fileprivate var recentValue: T?
    private var isCompleted = false
    
    public func send(_ value: T) {
        recentValue = value
        for (_, continuation) in continuations {
            continuation.yield(value)
        }
    }
    
    public func completion(_ error: Error?) {
        guard !isCompleted else { return }
        recentValue = nil
        isCompleted = true
        for (_, continuation) in continuations {
            if let error {
                continuation.finish(throwing: error)
            } else {
                continuation.finish()
            }
        }
        continuations.removeAll()
    }
    
    public func subscribe() -> Subject {
        if isCompleted {
            return Subject { continuation in
                continuation.finish()
            }
        } else {
            let uuid = UUID()
            return Subject { continuation in
                continuation.onTermination = { [weak self] finished in
                    guard let self else { return }
                    Task {
                        await self.drop(uuid)
                    }
                }
                continuations[uuid] = continuation
                logger.trace("add continuation for \(uuid), total \(continuations.count) subscribers")
                if let recentValue {
                    continuation.yield(recentValue)
                }
            }
        }
    }
    
    public func subscribe(_ continuation: Subject.Continuation) {
        if isCompleted {
            return
        } else {
            let uuid = UUID()
            continuation.onTermination = { [weak self] finished in
                guard let self else { return }
                Task {
                    await self.drop(uuid)
                }
            }
            continuations[uuid] = continuation
            logger.trace("add continuation for \(uuid), total \(continuations.count) subscribers")
        }
    }
    
    private func drop(_ id: UUID) {
        logger.trace("remove continuation for \(id), total \(continuations.count) subscribers")
        self.continuations.removeValue(forKey: id)
    }
    
    public func subscribersCount() -> Int {
        continuations.count
    }
}

public struct AsyncSubject<T: Sendable>: Sendable {
    public typealias Subject = AsyncThrowingStream<T, Error>
    private var holder = AsyncSubjectHolder<T>()
    
    public var currentValue: T? {
        get async {
            await holder.recentValue
        }
    }
    
    public init() {
        
    }
    
    public func send(_ value: T) {
        Task { @AsyncSubjectActor in
            await holder.send(value)
        }
    }
    
    public func completion(_ error: Error?) {
        Task { @AsyncSubjectActor in
            await holder.completion(error)
        }
    }
    
    public func subscribe() -> Subject {
        Subject { continuation in
            Task { @AsyncSubjectActor in
                await holder.subscribe(continuation)
            }
        }
    }
    
    public func subscribersCount() async -> Int {
        await holder.subscribersCount()
    }
}

//public protocol AsyncValueDummySequence: AsyncSequence {
//    
//}
//
//public protocol AsyncValuePatchSequence {
//    associatedtype Failure: Error
//}
//
//public protocol AsyncValueSequence<Element, Failure>: AsyncValueDummySequence, AsyncValuePatchSequence {
//    
//}
//
//extension AsyncMapSequence: AsyncValueSequence {
//    
//}
//
//extension AsyncCompactMapSequence: AsyncValueSequence {
//    
//}
//
//extension AsyncFilterSequence: AsyncValueSequence {
//    
//}
