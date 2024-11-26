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

public struct AsyncDownloadSession: AsyncCustomURLSession {
    public let id = UUID()
    public let delegate: AsyncURLSessiobDownloadDelegate
    public let tagsTaskIdenfier: any TaskIdentifiable
    private let urlSessionContainer: URLSessionHolder
    private let downloads: AsyncSubject<AsyncUpdateNews>

    public init(delegate: AsyncURLSessiobDownloadDelegate, tagsTaskIdenfier: any TaskIdentifiable) {
        self.delegate = delegate
        self.tagsTaskIdenfier = tagsTaskIdenfier
        self.urlSessionContainer = URLSessionHolder(delegate)
        let downloads = AsyncSubject<AsyncUpdateNews>()
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

    public func downloadWithProgress(_ request: URLRequestBuilder, tag: TaskTag) async throws -> AsyncThrowingStream<AsyncUpdateNews, Error> {
        let subject = try await AsyncDownloadURLProgressPublisher(request: request, tag: tag, delegtor: delegate, sessionProvider: self)
            .download()
            .map({
                AsyncUpdateNews(value: $0, tag: tag)
            })
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await item in subject {
                        continuation.yield(item)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func downloadNews(_ tag: TaskTag) -> AsyncThrowingStream<AsyncUpdateNews, Error> {
        let subject = delegate.news(self, tag: tag).map { AsyncUpdateNews(value: $0, tag: tag) }
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await item in subject {
                        continuation.yield(item)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func downloadNews() -> AsyncThrowingStream<AsyncUpdateNews, Error> {
        let subject = delegate.statePassthroughSubject
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await item in subject.subscribe() {
                        guard let tag = await self.tag(for: item.identifier) else {
                            continue
                        }
                        //  AsyncCompactMapSequence<AsyncThrowingStream<AsyncUpdateNews, Error>, AsyncUpdateNews>
                        continuation.yield(AsyncUpdateNews(value: item, tag: tag))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    public func requestBySetCookies(with request: URLRequestBuilder) throws -> URLRequestBuilder {
        try request.setCookies(with: urlSessionContainer.session)
    }
    
    public func cookies() -> [HTTPCookie] {
        urlSessionContainer.cookies.cookies ?? []
    }
    
    public func cancel(_ tag: TaskTag) async throws {
        let urlClient = client()
        guard let identifier = await taskIdentifier(for: tag) else {
            logger.warning("task identifier for tag [\(tag)] not found, unable to cancel it's task")
            return
        }
        try await urlClient.cancelTask(identifier)
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
