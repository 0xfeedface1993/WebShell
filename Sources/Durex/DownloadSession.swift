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

public struct AsyncDownloadSession: AsyncCustomURLSession {
    public let id = UUID()
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
    
    public func cookies() -> [HTTPCookie] {
        urlSessionContainer.cookies.cookies ?? []
    }
    
    public func cancel<TagValue: Hashable>(_ tag: TagValue) async throws {
        let urlClient = client()
        guard let identifier = await taskIdentifier(for: tag) else {
            logger.warning("task identifier for tag [\(tag)] not found, unable to cancel it's task")
            return
        }
        try await urlClient.cancelTask(identifier)
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
