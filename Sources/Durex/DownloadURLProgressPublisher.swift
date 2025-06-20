//
//  File.swift
//
//
//  Created by john on 2023/5/2.
//

import Foundation
import AsyncBroadcaster

#if COMBINE_LINUX && canImport(CombineX)
import CombineX
#else
import Combine
#endif
import Logging
#if canImport(AnyErase)
import AnyErase
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct OptionalIntWrapper<Item: Equatable> {
    let lhs: Item?
    let rhs: Item
    
    @inlinable
    init(_ lhs: Item?, _ rhs: Item) {
        self.lhs = lhs
        self.rhs = rhs
    }
    
    @inlinable
    func value() -> Item {
        lhs ?? rhs
    }
}

public struct DownloadURLProgressPublisher: Publisher {
    public typealias Output = TaskNews
    public typealias Failure = Error
    
    public let request: URLRequest
    public let session: SessionProvider
    public let tag: Int?
    private var delegtor: URLSessionDelegator?
    
    public init(request: URLRequest, session: SessionProvider, tag: Int?) {
        self.request = request
        self.session = session
        self.delegtor = session.systemSession().delegate as? URLSessionDelegator
        self.tag = tag
    }
    
    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        subscriber.receive(subscription: Inner(parent: self, downstream: subscriber))
    }
    
    typealias Parent = DownloadURLProgressPublisher
    private class Inner<Downstream: Subscriber>: Subscription, CustomStringConvertible, CustomReflectable, CustomPlaygroundDisplayConvertible
    where
    Downstream.Input == Parent.Output,
    Downstream.Failure == Parent.Failure
    {
        var combineIdentifier: CombineIdentifier
        
        private let lock: Lock
        private var task: URLSessionDownloadTask?
        private var parent: Parent?
        private var downstream: Downstream?
        private var demand: Subscribers.Demand = .none
        private var downloadTaskCancellable: AnyCancellable?
        
        init(parent: Parent, downstream: Downstream) {
            self.combineIdentifier = CombineIdentifier()
            self.lock = Lock()
            self.parent = parent
            self.downstream = downstream
        }
        
        deinit {
            lock.cleanupLock()
        }
        
        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            guard let parent = parent else {
                logger.info("no DownloadURLPublisher in upstream of \(self)")
                lock.unlock()
                return
            }
            
            if task == nil {
                // Avoid issues around `self` before init by setting up only once here
                let task = parent.session.systemSession().downloadTask(with: parent.request)
                let tag = OptionalIntWrapper(parent.tag, task.taskIdentifier).value()
                parent.session.bind(task: task, tagHashValue: tag)
                if let delegator = parent.delegtor {
                    // 在任务第一个下载进度更新之前先发送一个开始状态，
                    // 用于传递taskIdentifier
                    
                    let taskResume = Future<URLSessionDownloadTask, Error> { promise in
                        logger.info("url task \(task.taskIdentifier) resume, cURL:\n\(parent.request.cURL(pretty: true))")
                        task.resume()
                        promise(.success(task))
                    }
                    
                    let completor: AnyPublisher<TaskNews, Error> = delegator.news(parent.session, tag: tag)
                        .prepend(.state(.init(progress: .init(totalUnitCount: 0), filename: nil, identifier: tag)))
                        .eraseToAnyPublisher()
                    
                    downloadTaskCancellable = completor
                        .combineLatest(taskResume)
                        .map(\.0)
                        .sink(receiveCompletion: receiveCompletion(_:), receiveValue: receiveValue(_:))
                }
                
                self.task = task
            }
            
            self.demand += demand
            lock.unlock()
        }
        
        private func receiveCompletion(_ completion: Subscribers.Completion<Error>) {
            lock.lock()
            guard demand > 0, parent != nil, let downstream = downstream else {
#if DEBUG
                logger.info("[\(type(of: self))] \(#function) no downstream or parent or demand = 0.")
#endif
                lock.unlock()
                return
            }
            
            let task = self.task
            if let task = task, let session = parent?.session {
                session.unbind(task: task)
            }
            parent = nil
            self.downstream = nil
            demand = .none
            self.task = nil
            downloadTaskCancellable = nil
            
            lock.unlock()
            switch completion {
            case .finished:
#if DEBUG
                logger.info("[\(type(of: self))] \(#function) .finished.")
#endif
                downstream.receive(completion: .finished)
            case .failure(let error):
#if DEBUG
                logger.error("[\(type(of: self))] \(#function) .error \(error).")
#endif
                downstream.receive(completion: .failure(error))
            }
        }
        
        private func receiveValue(_ news: TaskNews) {
            guard demand > 0, parent != nil, let downstream = downstream else {
#if DEBUG
                logger.info("[\(type(of: self))] \(#function) no downstream or parent or demand = 0.")
#endif
                return
            }
            
            _ = downstream.receive(news)
        }
        
        func cancel() {
#if DEBUG
            logger.info("[\(type(of: self))] \(#function) cancel.")
#endif
            lock.lock()
            guard parent != nil else {
                lock.unlock()
                return
            }
            
            let task = self.task
            let downloadTaskCancellable = self.downloadTaskCancellable
            if let task = task, let session = parent?.session {
                session.unbind(task: task)
            }
            parent = nil
            downstream = nil
            demand = .none
            self.task = nil
            self.downloadTaskCancellable = nil
            lock.unlock()
            
            task?.cancel()
            downloadTaskCancellable?.cancel()
        }
        
        var description: String { "DownloadURLProgressPublisher" }
        var customMirror: Mirror {
            lock.lock()
            defer { lock.unlock() }
            return Mirror(self, children: [
                "task": task as Any,
                "downstream": downstream as Any,
                "parent": parent as Any,
                "demand": demand,
            ])
        }
        var playgroundDescription: Any { description }
    }
}


extension URLSessionDelegator {
    /// 监听指定下载任务的下载进度、下载完成、下载失败事件，下载失败会转化为Error流，失败后会终止此事件流，请勿使用`.error()`枚举类型判断是否是失败
    /// - Parameters:
    ///   - session: session对象，每个session对象都保存对应任务tag的对应关系
    ///   - tag: 任务标识的hashValue，因为存储任务标识本身比较消耗内存，使用hashValue代替
    /// - Returns: 下载任务事件
    func news(_ session: SessionProvider, tag: Int) -> AnyPublisher<TaskNews, Error> {
        statePassthroughSubject
            .filter({ session.taskIdentifier(for: tag) == $0.identifier })
            .tryMap { value in
                switch value {
                case .error(let error):
                    throw error.error
                default:
                    return value
                }
            }
            .eraseToAnyPublisher()
    }
    
    func news(_ session: SessionProvider, tag: Int) -> AnyPublisher<TaskNews, Never> {
        statePassthroughSubject
            .filter({ session.taskIdentifier(for: tag) == $0.identifier })
            .eraseToAnyPublisher()
    }
    
    /// 监听指定下载任务的下载进度、下载完成、下载失败事件, 外部使用者需要自己匹配identifier转换成需要的事件流
    /// - Returns: 下载任务事件
    func news() -> AnyPublisher<TaskNews, Never> {
        statePassthroughSubject.eraseToAnyPublisher()
    }
    
    func news(for identifer: Int) -> AnyPublisher<TaskNews, Never> {
        statePassthroughSubject.filter({ $0.identifier == identifer }).eraseToAnyPublisher()
    }
}

struct DownloadURLErrorFilter {
    let result: Result<SessionComplete, DownloadURLError>
    let compare: (Int) -> Bool
    
    private func on(_ error: Error) -> AnyPublisher<SessionComplete, DownloadURLError> {
        if let taskError = error as? DownloadURLError, compare(taskError.task.taskIdentifier) {
            return Fail(error: taskError).eraseToAnyPublisher()
        }
        return Empty().eraseToAnyPublisher()
    }
    
    private func _on(_ error: Error) throws {
        if let taskError = error as? DownloadURLError, compare(taskError.task.taskIdentifier) {
            throw taskError
        }
    }
    
    func optional() throws -> SessionComplete? {
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            try _on(error)
            return nil
        }
    }
    
    func dropValue() throws -> SessionComplete? {
        switch result {
        case .success(_):
            return nil
        case .failure(let error):
            try _on(error)
            return nil
        }
    }
    
    func `catch`() -> AnyPublisher<SessionComplete, DownloadURLError> {
        switch result {
        case .success(let value):
            return Just(value).setFailureType(to: DownloadURLError.self).eraseToAnyPublisher()
        case .failure(let error):
            return on(error)
        }
    }
}

extension SessionTaskState {
    /// 内部下载状态转换为外部News状态
    /// - Parameters:
    ///   - taskState: 内部下载状态
    ///   - tag: 任务id
    /// - Returns: News下载状态
    func newsValue(tag: Int) -> TaskNews {
        let progress = Progress(totalUnitCount: totalBytesExpectedToWrite)
        progress.completedUnitCount = totalBytesWritten
        let state = TaskNews.State(progress: progress,
                                   filename: task.response?.suggestedFilename,
                                   identifier: tag)
        return .state(state)
    }
}

extension Publisher where Output == TaskNews, Failure == Never {
    /// 将下载失败会转化为Error流，失败后会终止此事件流，请勿使用`.error()`枚举类型判断是否是失败
    /// - Returns: 下载任务事件
    public func unwrap() -> AnyPublisher<Output, Error> {
        tryMap { value in
            switch value {
            case .error(let error):
                throw error.error
            default:
                return value
            }
        }
        .eraseToAnyPublisher()
    }
}

struct AsyncDownloadURLProgressPublisher: Sendable {
    typealias Output = TaskNews
    typealias Failure = Error
    
    let request: URLRequestBuilder
    let tag: TaskTag
    var delegtor: AsyncURLSessiobDownloadDelegate
    let sessionProvider: AsyncSessionProvider
    
    func download() async throws -> AsyncStream<TaskNews> {
        let urlRequest = try request.build()
        
        let task = sessionProvider
            .client()
            .asyncDownloadTask(from: urlRequest)
        await sessionProvider.bind(task: task.taskIdentifier, tag: tag)
        defer {
            task.resume()
            logger.info("get file curl: \n\(urlRequest.cURL())")
        }
        
        return delegtor.news(sessionProvider, tag: tag)
    }
}

extension AsyncURLSessiobDownloadDelegate {
    /// 监听指定下载任务的下载进度、下载完成、下载失败事件，下载失败会转化为Error流，失败后会终止此事件流，请勿使用`.error()`枚举类型判断是否是失败
    /// - Parameters:
    ///   - session: session对象，每个session对象都保存对应任务tag的对应关系
    ///   - tag: 任务标识的hashValue，因为存储任务标识本身比较消耗内存，使用hashValue代替
    /// - Returns: 下载任务事件
    func news(_ session: AsyncSessionProvider, tag: TaskTag) -> AsyncStream<TaskNews> {
        let sequeue = statePassthroughSubject
            .filter({
                await session.taskIdentifier(for: tag) == $0.identifier
            })
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continiation in
            let task = Task {
                for await value in sequeue {
                    continiation.yield(value)
                }
                continiation.finish()
            }
            continiation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    func filter(_ session: AsyncSessionProvider, tag: TaskTag) -> AsyncStream<TaskNews> {
        let sequeue = statePassthroughSubject
            .filter({
                await session.taskIdentifier(for: tag) == $0.identifier
            })
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continiation in
            let task = Task {
                for await value in sequeue {
                    continiation.yield(value)
                }
                continiation.finish()
            }
            continiation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    func news(for identifer: Int) -> AsyncStream<TaskNews> {
        let sequeue = statePassthroughSubject
            .filter({ $0.identifier == identifer })
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continiation in
            let task = Task {
                for await value in sequeue {
                    continiation.yield(value)
                }
                continiation.finish()
            }
            continiation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

fileprivate func observeNews<S: AsyncSequence>(_ stream: S, continuation: AsyncThrowingStream<TaskNews, Error>.Continuation, session: AsyncSessionProvider, tag: TaskTag) async where S.Element == TaskNews {
    do {
        for try await value in stream {
            let next: TaskNews
            switch value {
            case .error(let error):
                await session.unbind(tag: tag)
                throw error.error
            case .file(_):
                logger.info("\(tag) download completed.")
                await session.unbind(tag: tag)
                next = value
                continuation.yield(next)
                break
            default:
                logger.info("\(tag) download progress update.")
                next = value
                continuation.yield(next)
            }
        }
        continuation.finish()
    } catch {
        continuation.finish(throwing: error)
    }
}
