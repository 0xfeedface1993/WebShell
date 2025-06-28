//
//  File.swift
//  
//
//  Created by john on 2023/5/1.
//

import Foundation
#if COMBINE_LINUX && canImport(CombineX)
@preconcurrency import CombineX
import Logging
internal let logger = Logger(label: "com.ascp.download")
#else
@preconcurrency import Combine
#if canImport(os.Logger)
internal let logger = Logger(subsystem: "AnyErase", category: "AnyErase")
#else
import Logging
internal let logger = Logger(label: "com.webshell.anyerase")
#endif
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif


import AnyErase
import AsyncAlgorithms
import AsyncBroadcaster

final class URLSessionDelegator: NSObject, URLSessionDownloadDelegate, Sendable {
    private let downloadTaskUpdate = PassthroughSubject<SessionTaskState, Never>()
    private let downloadTaskCompletion = PassthroughSubject<Result<SessionComplete, DownloadURLError>, Never>()
    /// 状态更新，可监听此Subject进行下载进度、下载完成、下载失败三种类型类型事件更新
    let statePassthroughSubject = PassthroughSubject<TaskNews, Never>()
    private let stateCancellable: AnyCancellable
    
#if DEBUG
    @MainActor static var debugFlag = true
#endif
    
    override init() {
        let updator = downloadTaskUpdate.map { state in
            TaskNews.state(state.newsState())
        }
        
        let completor = downloadTaskCompletion.map { result in
            switch result {
            case .success(let value):
                return value.fileStone()
            case .failure(let error):
                return TaskNews.error(.init(error: error.error, identifier: error.task.taskIdentifier))
            }
        }
        
        stateCancellable = updator.merge(with: completor)
            .subscribe(statePassthroughSubject)
        
        super.init()
    }
    
    deinit {
        stateCancellable.cancel()
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let filename = UUID().uuidString
        let cachedURL = FileManager.default.temporaryDirectory
        let url = cachedURL.appendingPathComponent(filename)
        
        do {
            try FileManager.default.moveItem(at: location, to: url)
            logger.info("move tmp file to \(location)")
            SessionComplete(task: downloadTask, data: url)
                .pass(to: downloadTaskCompletion)
        } catch {
            downloadTaskCompletion.send(.failure(.init(task: downloadTask, error: error)))
            return
        }
        
        //        #if DEBUG
        //        if URLSessionDelegator.debugFlag {
        //            URLSessionDelegator.debugFlag = false
        //            downloadTaskCompletion.send(.failure(.init(task: downloadTask, error: URLError(.unknown, userInfo: [NSLocalizedDescriptionKey: "hit debug flag"]))))
        //        }   else    {
        //            SessionComplete(task: downloadTask, data: url)
        //                .pass(to: downloadTaskCompletion)
        //        }
        //        #else
        //        SessionComplete(task: downloadTask, data: url)
        //            .pass(to: downloadTaskCompletion)
        //        #endif
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        //#if DEBUG
        //        print(">>> [\(type(of: self))] file download state update: \(downloadTask), \(bytesWritten) / \(totalBytesExpectedToWrite)")
        //#endif
        
        SessionTaskState(downloadTask)
            .reciveBytes(bytesWritten)
            .totalBytesWritten(totalBytesWritten)
            .totalBytesExpectedToWrite(totalBytesExpectedToWrite)
            .pass(to: downloadTaskUpdate)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            downloadTaskCompletion.send(.failure(DownloadURLError(task: task, error: error)))
            return
        }
    }
}

public protocol AsyncURLSessiobDownloadDelegate: URLSessionDownloadDelegate {
    /// 状态更新，可监听此Subject进行下载进度、下载完成、下载失败三种类型类型事件更新
    var statePassthroughSubject: AsyncBroadcaster<TaskNews> { get }
}

final class AsyncURLSessionDelegator: NSObject, AsyncURLSessiobDownloadDelegate {
    //    private let downloadTaskUpdate = PassthroughSubject<SessionTaskState, Never>()
    //    private let downloadTaskCompletion = PassthroughSubject<Result<SessionComplete, DownloadURLError>, Never>()
    /// 状态更新，可监听此Subject进行下载进度、下载完成、下载失败三种类型类型事件更新
    let stateSubject: ChannelSubject<TaskNews>
    var statePassthroughSubject: AsyncBroadcaster<TaskNews> {
        stateSubject.subscribe()
    }
    let cachedFolder: URL
    
#if DEBUG
    @MainActor static var debugFlag = true
#endif
    
    init(_ cachedFolder: URL) {
        self.stateSubject = ChannelSubject<TaskNews>()
        self.cachedFolder = cachedFolder
        super.init()
    }
    
    deinit {
        self.stateSubject.finished()
    }
    
#if DEBUG
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest) async -> URLRequest? {
        let next = request
        //        response.
        //        next.setValue("", forHTTPHeaderField: "")
        logger.info("[\(task.taskIdentifier)] redirecting to curl: \n----------------\n\(next.cURL())")
        logger.info("[\(task.taskIdentifier)] redirection response headers: \(response.allHeaderFields)")
        return next
    }
#endif
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let filename = UUID().uuidString
        let cachedURL = cachedFolder
        let url = cachedURL.appendingPathComponent(filename)
        
        do {
            try FileManager.default.moveItem(at: location, to: url)
            logger.info("move tmp file to \(location)")
            let news = SessionComplete(task: downloadTask, data: url).fileStone()
            Task {
                await stateSubject.send(news)
            }
        } catch {
            let failure = UpdateFailure(error: error, identifier: downloadTask.taskIdentifier)
            let news = TaskNews.error(failure)
            logger.info("\(#function) download file task [\(downloadTask.taskIdentifier)] failed \(error), \n--------------\n curl: \(downloadTask.currentRequest?.cURL(pretty: true) ??  "Ooops!") ")
            Task {
                await stateSubject.send(news)
            }
        }
        
        //        #if DEBUG
        //        if URLSessionDelegator.debugFlag {
        //            URLSessionDelegator.debugFlag = false
        //            downloadTaskCompletion.send(.failure(.init(task: downloadTask, error: URLError(.unknown, userInfo: [NSLocalizedDescriptionKey: "hit debug flag"]))))
        //        }   else    {
        //            SessionComplete(task: downloadTask, data: url)
        //                .pass(to: downloadTaskCompletion)
        //        }
        //        #else
        //        SessionComplete(task: downloadTask, data: url)
        //            .pass(to: downloadTaskCompletion)
        //        #endif
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
//        #if DEBUG
//                print(">>> [\(type(of: self))] file download state update: \(downloadTask), \(bytesWritten) / \(totalBytesExpectedToWrite)")
//        #endif
//        logger.info("file download state update: \(downloadTask), \(totalBytesWritten) / \(totalBytesExpectedToWrite)")
//        logger.info("[\(downloadTask.taskIdentifier)] downloading response: \((downloadTask.response as? HTTPURLResponse)?.allHeaderFields ?? [:])")
        
        let bytes: Int64
        if totalBytesExpectedToWrite < bytesWritten, let contentLength = (downloadTask.response as? HTTPURLResponse)?.allHeaderFields["Content-Length"] as? Int64 {
            bytes = contentLength
            logger.info("[\(downloadTask.taskIdentifier)] downloading totalBytesExpectedToWrite \(totalBytesExpectedToWrite) bytes invalid, use task response Content-Length \(bytes) bytes.")
        } else {
            bytes = totalBytesExpectedToWrite
        }
        
        let state = SessionTaskState(downloadTask)
            .reciveBytes(bytesWritten)
            .totalBytesWritten(totalBytesWritten)
            .totalBytesExpectedToWrite(bytes)
            .newsState()
        let news = TaskNews.state(state)
        Task {
            await stateSubject.send(news)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            let failure = UpdateFailure(error: error, identifier: task.taskIdentifier)
            let news = TaskNews.error(failure)
            logger.info("\(#function) download file task [\(task.taskIdentifier)] failed \(error), \n--------------\n curl: \(task.currentRequest?.cURL(pretty: true) ??  "Ooops!") ")
            Task {
                await stateSubject.send(news)
            }
            return
        }
    }
}
