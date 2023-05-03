//
//  File.swift
//  
//
//  Created by john on 2023/5/2.
//

import Foundation
import Combine
import os.log
import AnyErase

fileprivate let logger = OSLog(subsystem: "com.ascp.publisher", category: "DownloadURLProgressPublisher")

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
    public enum News: Equatable {
        case state(State)
        case file(URL, URLResponse)
        
        public struct State: Equatable {
            public let progress: Progress
            public let filename: String?
            public let identifier: Int
            
            public static let none = State(progress: .init(), filename: nil, identifier: 0)
            
            init(progress: Progress, filename: String?, identifier: Int) {
                self.progress = progress
                self.filename = filename
                self.identifier = identifier
            }
            
            public func tag(_ value: Int) -> State {
                State(progress: progress, filename: filename, identifier: value)
            }
        }
    }
    
    public typealias Output = News
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
                os_log("no DownloadURLPublisher in upstream.", log: logger, type: .debug)
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
                    downloadTaskCancellable = delegator.newsCompletor(task.taskIdentifier)
                        .prepend(.state(.init(progress: .init(totalUnitCount: 0), filename: nil, identifier: tag)))
                        .sink(receiveCompletion: receiveCompletion(_:), receiveValue: receiveValue(_:))
                }
                
                self.task = task
            }
            
            self.demand += demand
            let task = self.task
            lock.unlock()
            
            task?.resume()
        }
        
        private func receiveCompletion(_ completion: Subscribers.Completion<Error>) {
            lock.lock()
            guard demand > 0, parent != nil, let downstream = downstream else {
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
                downstream.receive(completion: .finished)
            case .failure(let error):
                downstream.receive(completion: .failure(error))
            }
        }
        
        private func receiveValue(_ news: Parent.News) {
            guard demand > 0, parent != nil, let downstream = downstream else {
                return
            }
            
            _ = downstream.receive(news)
        }
        
        func cancel() {
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
    /// 将result转化成try-catch流
    /// - Parameter result: result对象
    /// - Returns: 存在的值
    @inlinable
    func tryMapResult<T, V>(_ result: Result<T, V>) throws -> T {
        try result.get()
    }
    
    /// 分解SessionComplete：，下载文件URL、请求响应、taskIdentifier三部分
    /// - Parameter complete: 下载完成SessionComplete事件
    /// - Returns: 下载文件URL、请求响应、taskIdentifier
    func splitThree(_ complete: SessionComplete) -> (URL, URLResponse, Int)? {
        if let response = complete.task.response {
            return (complete.data, response, complete.task.taskIdentifier)
        }
#if DEBUG
        print(">>> can't split complete \(complete), because response is nil")
#endif
        return nil
    }
    
    /// 转换内部下载完成事件为外部RawNews，不匹配complete.task.taskIdentifier，没有response则返回nil
    /// - Parameter complete: 内部下载完成事件
    /// - Returns: 外部下载完成RawNews
    func rawCompleteToRawNews(_ complete: SessionComplete) -> RawNews? {
        if let response = complete.task.response {
            return RawNews(.file(complete.data, response), taskIdentifier: complete.task.taskIdentifier)
        }
#if DEBUG
        print(">>> can't convert rawCompleteToRawNews \(complete), because response is nil")
#endif
        return nil
    }
    
    fileprivate func newsCompletor(_ taskIdentifier: Int) -> AnyPublisher<DownloadURLProgressPublisher.News, Error> {
        downloadTaskCompletion
            .tryMap(tryMapResult(_:))
            .compactMap(splitThree(_:))
            .filter { $0.2 == taskIdentifier }
            .map { DownloadURLProgressPublisher.News.file($0.0, $0.1) }
            .mapError({ $0 as Error })
            .eraseToAnyPublisher()
    }
    
    fileprivate func newsUpdator(_ taskIdentifier: Int, tag: Int) -> AnyPublisher<DownloadURLProgressPublisher.News, Error> {
        downloadTaskUpdate
            .filter({ $0.task.taskIdentifier == taskIdentifier })
            .map { $0.newsValue(tag: tag) }
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    fileprivate func rawNewsCompletor() -> AnyPublisher<RawNews, Error> {
        downloadTaskCompletion
            .tryMap(tryMapResult(_:))
            .compactMap(rawCompleteToRawNews(_:))
            .eraseToAnyPublisher()
    }
    
    fileprivate func rawNewsUpdator() -> AnyPublisher<RawNews, Error> {
        downloadTaskUpdate
            .map { RawNews($0.newsValue(tag: 0), taskIdentifier: $0.task.taskIdentifier) }
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func news(_ session: SessionProvider, tag: Int) -> AnyPublisher<DownloadURLProgressPublisher.News, Error> {
        rawNewsUpdator()
            .merge(with: rawNewsCompletor())
            .filter({ session.taskIdentifier(for: tag) == $0.taskIdentifier })
            .map(\.data)
            .eraseToAnyPublisher()
    }
}

struct RawNews {
    let data: DownloadURLProgressPublisher.News
    let taskIdentifier: Int
    
    init(_ data: DownloadURLProgressPublisher.News, taskIdentifier: Int) {
        self.data = data
        self.taskIdentifier = taskIdentifier
    }
    
    func tag(_ value: Int) -> Self {
        switch data {
        case .state(let state):
            return .init(.state(state.tag(value)), taskIdentifier: taskIdentifier)
        case .file(_, _):
            return .init(data, taskIdentifier: taskIdentifier)
        }
    }
}

extension SessionTaskState {
    /// 内部下载状态转换为外部News状态
    /// - Parameters:
    ///   - taskState: 内部下载状态
    ///   - tag: 任务id
    /// - Returns: News下载状态
    func newsValue(tag: Int) -> DownloadURLProgressPublisher.News {
        let progress = Progress(totalUnitCount: totalBytesExpectedToWrite)
        progress.completedUnitCount = totalBytesWritten
        let state = DownloadURLProgressPublisher
            .News
            .State(progress: progress,
                   filename: task.response?.suggestedFilename,
                   identifier: tag)
        return .state(state)
    }
}
