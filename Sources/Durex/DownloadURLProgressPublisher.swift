//
//  File.swift
//  
//
//  Created by john on 2023/5/2.
//

import Foundation
import Combine
import os.log
#if canImport(AnyErase)
import AnyErase
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
//    /// 分解SessionComplete：，下载文件URL、请求响应、taskIdentifier三部分
//    /// - Parameter complete: 下载完成SessionComplete事件
//    /// - Returns: 下载文件URL、请求响应、taskIdentifier
//    func splitThree(_ complete: SessionComplete) -> (URL, URLResponse, Int)? {
//        if let response = complete.task.response {
//            return (complete.data, response, complete.task.taskIdentifier)
//        }
//#if DEBUG
//        logger.info("can't split complete \(complete), because response is nil")
//#endif
//        return nil
//    }
    
//    /// 转换内部下载完成事件为外部RawNews，不匹配complete.task.taskIdentifier，没有response则返回nil
//    /// - Parameter complete: 内部下载完成事件
//    /// - Returns: 外部下载完成RawNews
//    func rawCompleteToRawNews(_ complete: SessionComplete) -> RawNews? {
//        if let response = complete.task.response {
//            return RawNews(.file(.init(url: complete.data, response: response, identifier: complete.task.taskIdentifier)), taskIdentifier: complete.task.taskIdentifier)
//        }
//#if DEBUG
//        logger.info("can't convert rawCompleteToRawNews \(complete), because response is nil")
//#endif
//        return nil
//    }
//
//    fileprivate func newsCompletor(_ taskIdentifier: Int) -> AnyPublisher<DownloadURLProgressPublisher.News, Error> {
//        downloadTaskCompletion
//            .tryMap({ job in
//                try DownloadURLErrorFilter(result: job, compare: { $0 == taskIdentifier })
//                    .optional()
//            })
//            .compactMap({ $0 })
//            .eraseToAnyPublisher()
//            .compactMap(splitThree(_:))
//            .filter { $0.2 == taskIdentifier }
//            .map { DownloadURLProgressPublisher.News.file(.init(url: $0.0, response: $0.1, identifier: $0.2)) }
//            .mapError({ $0 as Error })
//            .eraseToAnyPublisher()
//    }
//
//    fileprivate func newsUpdator(_ taskIdentifier: Int, tag: Int) -> AnyPublisher<DownloadURLProgressPublisher.News, Error> {
//        downloadTaskUpdate
//            .filter({ $0.task.taskIdentifier == taskIdentifier })
//            .map { $0.newsValue(tag: tag) }
//            .setFailureType(to: Error.self)
//            .eraseToAnyPublisher()
//    }
//
//    /// 生成新的下载完成事件publisher，这里之所以要匹配taskIdentifier
//    /// 是因为如果上游的事件被`tryMapResult`转换成failure时不匹配当前任务
//    /// 则会导致本任务的异常失败，下游无法得到状态更新
//    /// - Parameter taskIdentifier: 匹配taskIdentifier方法
//    /// - Returns: 只有有成功完成事件发送
//    fileprivate func rawNewsCompletor(_ taskIdentifier: @escaping (Int) -> Bool) -> AnyPublisher<RawNews, Error> {
//        downloadTaskCompletion
//            .tryMap({ job in
//                try DownloadURLErrorFilter(result: job, compare: taskIdentifier)
//                    .optional()
//            })
//            .compactMap({ $0 })
//            .filter({ taskIdentifier($0.task.taskIdentifier) })
//            .compactMap(rawCompleteToRawNews(_:))
//            .eraseToAnyPublisher()
//    }
//
//    fileprivate func rawNewsUpdator() -> AnyPublisher<RawNews, Error> {
//        downloadTaskUpdate
//            .map { RawNews($0.newsValue(tag: 0), taskIdentifier: $0.task.taskIdentifier) }
//            .setFailureType(to: Error.self)
//            .eraseToAnyPublisher()
//    }
//
//    /// 只提取Error事件, 普通的value丢弃，为了处理news里面错误事件无法传递的问题
//    /// - Parameter taskIdentifier: 匹配taskIdentifier方法
//    /// - Returns: 只有失败事件发送
//    private func completeError(_ taskIdentifier: @escaping (Int) -> Bool) -> AnyPublisher<RawNews, Error> {
//        downloadTaskCompletion
//            .tryMap({ job in
//                // 将value转为nil，错误则抛出Error
//                try DownloadURLErrorFilter(result: job, compare: taskIdentifier)
//                    .dropValue()
//            })
//            // 丢弃nil值
//            .compactMap({ $0 })
//            .filter({ taskIdentifier($0.task.taskIdentifier) })
//            .compactMap(rawCompleteToRawNews(_:))
//            .eraseToAnyPublisher()
//    }
    
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

//struct RawNews {
//    let data: DownloadURLProgressPublisher.News
//    let taskIdentifier: Int
//
//    init(_ data: DownloadURLProgressPublisher.News, taskIdentifier: Int) {
//        self.data = data
//        self.taskIdentifier = taskIdentifier
//    }
//
//    func tag(_ value: Int) -> Self {
//        switch data {
//        case .state(let state):
//            return .init(.state(state.tag(value)), taskIdentifier: taskIdentifier)
//        case .file(_):
//            return .init(data, taskIdentifier: taskIdentifier)
//        }
//    }
//}

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
