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
import AsyncBroadcaster
import AsyncAlgorithms

public struct AsyncDownloadSession: AsyncCustomURLSession {
    public let id = UUID()
    public let delegate: AsyncURLSessiobDownloadDelegate
    public let tagsTaskIdenfier: any TaskIdentifiable
    private let urlSessionContainer: URLSessionHolder
    private let downloads: AsyncChannel<AsyncUpdateNews>

    public init(delegate: AsyncURLSessiobDownloadDelegate, tagsTaskIdenfier: any TaskIdentifiable) {
        self.delegate = delegate
        self.tagsTaskIdenfier = tagsTaskIdenfier
        self.urlSessionContainer = URLSessionHolder(delegate)
        let downloads = AsyncChannel<AsyncUpdateNews>()
        self.downloads = downloads
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

    public func downloadWithProgress(_ request: URLRequestBuilder, tag: TaskTag) async throws -> AsyncStream<AsyncUpdateNews> {
        let publisher = AsyncDownloadURLProgressPublisher(request: request, tag: tag, delegtor: delegate, sessionProvider: self)
        let (stream, continuation) = AsyncStream.makeStream(of: AsyncUpdateNews.self, bufferingPolicy: .unbounded)
        let task = Task {
            do {
                for try await item in try await publisher.download() {
//                        logger.info("[\("\(tag)")] recevice \("\(item)")")
                    continuation.yield(AsyncUpdateNews(value: item, tag: tag))
                    switch item {
                    case .error, .file:
                        break
                    default:
                        continue
                    }
                }
            } catch {
                continuation.yield(
                    AsyncUpdateNews(value: .error(.init(error: error, identifier: 900)), tag: tag)
                )
            }
//                logger.info("[\("\(tag)")] finish continuation.")
            continuation.finish()
        }
        continuation.onTermination = { t in
            task.cancel()
        }
        return stream
    }

    public func downloadNews(_ tag: TaskTag) -> AsyncStream<AsyncUpdateNews> {
        let (stream, continuation) = AsyncStream<AsyncUpdateNews>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let sequeue = delegate.news(self, tag: tag)
        let task = Task {
            for try await item in sequeue {
                logger.info("[\("\(tag)")] downloadNews yield \("\(item)")")
                continuation.yield(AsyncUpdateNews(value: item, tag: tag))
                switch item {
                case .error, .file:
                    break
                default:
                    continue
                }
            }
//            logger.info("[\("\(tag)")] downloadNews finished")
            continuation.finish()
        }
        continuation.onTermination = { t in
            task.cancel()
        }
        return stream
    }
    
    public func downloadNews() -> AsyncStream<AsyncUpdateNews> {
        let subject = delegate.statePassthroughSubject
        let (stream, continuation) = AsyncStream<AsyncUpdateNews>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let task = Task {
            for await value in subject.compactMap({ item -> AsyncUpdateNews? in
                guard let tag = await tag(for: item.identifier) else {
                    return nil
                }
                return AsyncUpdateNews(value: item, tag: tag)
            }) {
                continuation.yield(value)
            }
            continuation.finish()
        }
        continuation.onTermination = { _ in
            task.cancel()
        }
        return stream
    }
    
    public func requestBySetCookies(with request: URLRequestBuilder) throws -> URLRequestBuilder {
        try request.setCookies(with: urlSessionContainer.session)
    }
    
    public func cookies() -> [HTTPCookie] {
        urlSessionContainer.cookies.cookies ?? []
    }
    
    public func mergeCookies(_ newCookies: [HTTPCookie]) {
        newCookies.forEach(urlSessionContainer.cookies.setCookie)
    }
    
    public func cancel(_ tag: TaskTag) async throws {
        let urlClient = client()
        guard let identifier = await taskIdentifier(for: tag) else {
            logger.warning("task identifier for tag [\(tag)] not found, unable to cancel it's task")
            return
        }
        try await urlClient.cancelTask(identifier)
    }
    
    public func runningTasks() async -> [(TaskTag, URLSessionDownloadTask)] {
        let tasks = await urlSessionContainer
            .session
            .tasks()
            .compactMap { $0 as? URLSessionDownloadTask }
        var temp = [(TaskTag, URLSessionDownloadTask)]()
        for task in tasks {
            guard let tag = await tagsTaskIdenfier.tag(for: task.taskIdentifier) else {
                continue
            }
            temp.append((tag, task))
        }
        return temp
    }
}

extension AsyncDownloadSession: AsyncSessionProvider {
    public func unbind(tag: TaskTag) async {
        let represemtTag = tag
//        logger.info("unbind tag \(represemtTag)")
        await tagsTaskIdenfier.remove(tag: represemtTag)
    }
    
    public func bind(task: TaskIdentifier, tag: TaskTag) async {
//        logger.info("bind tag \(tag) with task \(task)")
        await tagsTaskIdenfier.set(tag, for: task)
    }
    
    public func unbind(task: TaskIdentifier) async {
//        logger.info("unbind task \(task)")
        await tagsTaskIdenfier.remove(taskIdentifier: task)
    }
    
    public func client() -> AnyErase.URLClient {
        urlSessionContainer.session
    }
    
    public func tag(for taskIdentifier: TaskIdentifier) async -> TaskTag? {
        let tag = await tagsTaskIdenfier.tag(for: taskIdentifier)
//        if let tag = tag {
//            logger.info("get tag \(tag) from task \(taskIdentifier)")
//        }   else    {
//            logger.info("no tag from task \(taskIdentifier)")
//        }
        return tag
    }
    
    public func taskIdentifier(for tag: TaskTag) async -> TaskIdentifier? {
        let represemtTag = tag
        let task = await tagsTaskIdenfier.taskIdentifier(for: represemtTag)
//        if let task = task {
//            logger.info("get task \(task) from tag \(represemtTag)")
//        }   else    {
//            logger.info("no task from tag \(represemtTag)")
//        }
        return task
    }
}
