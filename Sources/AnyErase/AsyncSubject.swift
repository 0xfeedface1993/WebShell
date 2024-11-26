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
    
    public func send(_ value: T) {
        for (_, continuation) in continuations {
            continuation.yield(value)
        }
    }
    
    public func completion(_ error: Error?) {
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
        }
    }
    
    public func subscribe(_ continuation: Subject.Continuation) {
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
    
    private func drop(_ id: UUID) {
        logger.trace("remove continuation for \(id), total \(continuations.count) subscribers")
        self.continuations.removeValue(forKey: id)
    }
}

public struct AsyncSubject<T: Sendable>: Sendable {
    public typealias Subject = AsyncThrowingStream<T, Error>
    private var holder = AsyncSubjectHolder<T>()
    
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
