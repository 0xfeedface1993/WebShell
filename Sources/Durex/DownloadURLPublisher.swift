//
//  File.swift
//  
//
//  Created by john on 2023/5/2.
//

import Foundation
#if COMBINE_LINUX && canImport(CombineX)
import CombineX
#else
@preconcurrency import Combine
#endif
import Logging
#if canImport(AnyErase)
import AnyErase
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct DownloadURLPublisher: Publisher, Sendable {
    public typealias Output = (URL, URLResponse)
    public typealias Failure = Error
    
    public let request: URLRequest
    public let session: URLSession
    
    public init(request: URLRequest, session: URLSession) {
        self.request = request
        self.session = session
    }
    
    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        subscriber.receive(subscription: Inner(parent: self, downstream: subscriber))
    }
    
    private class Inner<Downstream: Subscriber>: Subscription, CustomStringConvertible, CustomReflectable, CustomPlaygroundDisplayConvertible, @unchecked Sendable
        where
            Downstream.Input == DownloadURLPublisher.Output,
            Downstream.Failure == DownloadURLPublisher.Failure
    {
        var combineIdentifier: CombineIdentifier
        
        private let lock: Lock
        private var task: URLSessionDownloadTask?
        private var parent: DownloadURLPublisher?
        private var downstream: Downstream?
        private var demand: Subscribers.Demand = .none
        
        init(parent: DownloadURLPublisher, downstream: Downstream) {
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
                let task = parent.session.downloadTask(with: parent.request, completionHandler: downloadComplete(_:response:error:))
                self.task = task
            }
            
            self.demand += demand
            let task = self.task
            lock.unlock()
            
            logger.info("url task \(task?.taskIdentifier ?? 0), cURL:\n\(parent.request.cURL(pretty: true))")
            task?.resume()
        }
        
        private func downloadComplete(_ url: URL?, response: URLResponse?, error: Error?) {
            lock.lock()
            guard demand > 0, parent != nil, let downstream = downstream else {
                lock.unlock()
                return
            }
            
            parent = nil
            self.downstream = nil
            
            demand = .none
            task = nil
            lock.unlock()
            
            if let url = url, let response = response, error == nil {
                _ = downstream.receive((url, response))
                downstream.receive(completion: .finished)
            }   else    {
                let urlError = error ?? URLError(.unknown)
                downstream.receive(completion: .failure(urlError))
            }
        }
        
        func cancel() {
            lock.lock()
            guard parent != nil else {
                lock.unlock()
                return
            }
            
            parent = nil
            downstream = nil
            demand = .none
            let task = self.task
            self.task = nil
            lock.unlock()
            
            task?.cancel()
        }
        
        var description: String { "DownloadURLPublisher" }
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

struct AsyncDownloadURLPublisher {
    typealias Output = (URL, URLResponse)
    typealias Failure = Error
    
    let request: URLRequestBuilder
    let session: any URLClient
    
    init(_ request: URLRequestBuilder) {
        self.request = request
        self.session = URLSession.shared
    }
    
    init(_ request: URLRequestBuilder, session: any URLClient) {
        self.request = request
        self.session = session
    }
    
    func session(_ value: any URLClient) -> Self {
        .init(request, session: session)
    }
    
    func download() async throws -> Output {
        let next = try request.build()
        return try await session.asyncDownload(from: next)
    }
}
