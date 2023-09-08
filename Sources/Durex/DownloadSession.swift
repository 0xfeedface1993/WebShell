//
//  File.swift
//  
//
//  Created by john on 2023/5/1.
//

import Foundation
#if COMBINE_LINUX && canImport(CombineX)
import CombineX
#else
import Combine
#endif
#if canImport(AnyErase)
import AnyErase
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import Logging
import AsyncExtensions

//extension CustomURLSession {
//    /// 全局共享下载session
//    /// - Returns: 共享session
//    static func shared() -> CustomURLSession {
//        DownloadSession._shared
//    }
//}

//public final class DownloadSession: CustomURLSession {
//    fileprivate static let _shared = DownloadSession()
//    private let delegator = URLSessionDelegator()
//    private lazy var _session = URLSessionHolder(delegator)
//    private var tagsCached = [Int: Int]()
//    private let lock = Lock()
//
//    public init() {
//
//    }
//
//    deinit {
//        lock.cleanupLock()
//    }
//
//    public func downloadWithProgress(_ request: URLRequest, tag: AnyHashable? = nil) -> DownloadURLProgressPublisher {
//        DownloadURLProgressPublisher(request: request, session: self, tag: tag?.hashValue)
//    }
//
//    public func download(with request: URLRequest) -> AnyPublisher<(URL, URLResponse), Error> {
//        DownloadURLPublisher(request: request, session: systemSession())
//            .eraseToAnyPublisher()
//    }
//
//    public func data(with request: URLRequest) -> AnyPublisher<Data, Error> {
//        download(with: request)
//            .tryMap { url in
//                try Data(contentsOf: url.0)
//            }
//            .eraseToAnyPublisher()
//    }
//
//    public func downloadNews(for identifier: AnyHashable) -> AnyPublisher<UpdateNews, Error> {
//        delegator.news(self, tag: identifier.hashValue)
//            .map {
//                UpdateNews(value: $0, tagHashValue: identifier.hashValue)
//            }
//            .eraseToAnyPublisher()
//    }
//
//    public func downloadWrapNews(for identifier: AnyHashable) -> AnyPublisher<UpdateNews, Never> {
//        delegator.news(self, tag: identifier.hashValue)
//            .map {
//                UpdateNews(value: $0, tagHashValue: identifier.hashValue)
//            }
//            .eraseToAnyPublisher()
//    }
//
//    public func downloadNews() -> AnyPublisher<UpdateNews, Never> {
//        delegator.news()
//            .map {
//                UpdateNews(value: $0, tagHashValue: self.tag(for: $0.identifier))
//            }
//            .eraseToAnyPublisher()
//    }
//}
//
//extension DownloadSession: SessionProvider {
//    public func systemSession() -> URLSession {
//        _session.session as? URLSession ?? .shared
//    }
//
//    public func bind(task: URLSessionDownloadTask, tagHashValue: Int) {
//        lock.lock()
//        let identifier = task.taskIdentifier
//        let value = tagsCached[identifier]
//        tagsCached[identifier] = tagHashValue
//        lock.unlock()
//        if let value = value {
//            logger.info("download task \(identifier) already has tag \(value)")
//        }
//        logger.info("download task \(identifier) add new tag \(tagHashValue)")
//    }
//
//    public func unbind(task: URLSessionDownloadTask) {
//        lock.lock()
//        let identifier = task.taskIdentifier
//        tagsCached.removeValue(forKey: identifier)
//        lock.unlock()
//        logger.info("download task \(identifier) remove tag")
//    }
//
//    @inlinable
//    public func tag(for task: URLSessionDownloadTask) -> Int {
//        tag(for: task.taskIdentifier)
//    }
//
//    public func tag(for taskIdentifier: Int) -> Int {
//        lock.lock()
//        let identifier = taskIdentifier
//        let value = tagsCached[identifier]
//        lock.unlock()
////        if let value = value {
////            os_log(.debug, log: logger, "download task %d retrive tag %d", identifier, value)
////        }   else    {
////            os_log(.debug, log: logger, "download task %d has no tag", identifier)
////        }
//        return value ?? identifier
//    }
//
//    public func taskIdentifier(for tag: Int) -> Int? {
//        lock.lock()
//        let value = tagsCached.first(where: { $0.value == tag })?.key
//        lock.unlock()
////        if let value = value {
////            os_log(.debug, log: logger, "download tag %d retrive task %d", tag, value)
////        }   else    {
////            os_log(.debug, log: logger, "download tag %d has no task", tag)
////        }
//        return value
//    }
//}
//
public struct AsyncDownloadSession: AsyncCustomURLSession {
    public let delegate: AsyncURLSessiobDownloadDelegate
    public let tagsTaskIdenfier: any TaskIdentifiable
    private let urlSessionContainer: URLSessionHolder

    public init(delegate: AsyncURLSessiobDownloadDelegate, tagsTaskIdenfier: any TaskIdentifiable) {
        self.delegate = delegate
        self.tagsTaskIdenfier = tagsTaskIdenfier
        self.urlSessionContainer = URLSessionHolder(delegate)
    }

    public func data(with request: URLRequestBuilder) async throws -> Data {
        let (url, _) = try await download(with: request)
        return try Data(contentsOf: url)
    }

    public func download(with request: URLRequestBuilder) async throws -> (URL, URLResponse) {
        try await AsyncDownloadURLPublisher(request)
            .session(urlSessionContainer.session)
            .download()
    }

    public func downloadWithProgress<TagValue>(_ request: URLRequestBuilder, tag: TagValue) async throws -> AnyAsyncSequence<AsyncUpdateNews> where TagValue : Hashable {
        try await AsyncDownloadURLProgressPublisher(request: request, tag: tag, delegtor: delegate, sessionProvider: self)
            .download()
            .map({
                AsyncUpdateNews(value: $0, tag: tag)
            })
            .eraseToAnyAsyncSequence()
    }

    public func downloadNews<TagValue>(_ tag: TagValue) -> AsyncExtensions.AnyAsyncSequence<AsyncUpdateNews> where TagValue : Hashable {
        delegate.news(self, tag: tag)
            .map({
                AsyncUpdateNews(value: $0, tag: tag)
            })
            .eraseToAnyAsyncSequence()
    }

    public func downloadNews() -> AnyAsyncSequence<AsyncUpdateNews> {
        delegate
            .statePassthroughSubject
            .compactMap {
                guard let tag = await self.tag(for: $0.identifier) else {
                    return nil
                }
                return AsyncUpdateNews(value: $0, tag: tag)
            }
            .eraseToAnyAsyncSequence()
    }
    
    public func requestBySetCookies(with request: URLRequestBuilder) throws -> URLRequestBuilder {
        try request.setCookies(with: urlSessionContainer.session)
    }
}

extension AsyncDownloadSession: AsyncSessionProvider {
    public func unbind<HashValue: Hashable>(tag: HashValue) async {
        let represemtTag = AnyHashable(tag)
//        logger.info("unbind tag \(represemtTag)")
        await tagsTaskIdenfier.remove(tag: represemtTag)
    }
    
    public func bind<HashValue: Hashable>(task: TaskIdentifier, tag: HashValue) async {
//        logger.info("bind tag \(tag) with task \(task)")
        await tagsTaskIdenfier.set(AnyHashable(tag), for: task)
    }
    
    public func unbind(task: TaskIdentifier) async {
//        logger.info("unbind task \(task)")
        await tagsTaskIdenfier.remove(taskIdentifier: task)
    }
    
    public func client() -> AnyErase.URLClient {
        urlSessionContainer.session
    }
    
    public func tag(for taskIdentifier: TaskIdentifier) async -> AnyHashable? {
        let tag = await tagsTaskIdenfier.tag(for: taskIdentifier)
//        if let tag = tag {
//            logger.info("get tag \(tag) from task \(taskIdentifier)")
//        }   else    {
//            logger.info("no tag from task \(taskIdentifier)")
//        }
        return tag
    }
    
    public func taskIdentifier<HashValue: Hashable>(for tag: HashValue) async -> TaskIdentifier? {
        let represemtTag = AnyHashable(tag)
        let task = await tagsTaskIdenfier.taskIdentifier(for: represemtTag)
//        if let task = task {
//            logger.info("get task \(task) from tag \(represemtTag)")
//        }   else    {
//            logger.info("no task from tag \(represemtTag)")
//        }
        return task
    }
}
