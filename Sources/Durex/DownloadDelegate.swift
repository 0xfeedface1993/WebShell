//
//  File.swift
//  
//
//  Created by john on 2023/5/1.
//

import Foundation
import Combine
import Logging

internal let logger = Logger(label: "com.ascp.download")

struct DownloadSessionError: Error {
    let originError: Error
    let task: URLSessionTask
    let date = Date()
}

struct SessionTaskState {
    let task: URLSessionDownloadTask
    let reciveBytes: Int64
    let totalBytesWritten: Int64
    let totalBytesExpectedToWrite: Int64
    
    var progress: Double {
        totalBytesExpectedToWrite > 0 ? (Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)):0.0
    }
    
    init(task: URLSessionDownloadTask, reciveBytes: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        self.task = task
        self.reciveBytes = reciveBytes
        self.totalBytesWritten = totalBytesWritten
        self.totalBytesExpectedToWrite = totalBytesExpectedToWrite
    }
    
    init(_ task: URLSessionDownloadTask) {
        self.task = task
        self.reciveBytes = 0
        self.totalBytesWritten = 0
        self.totalBytesExpectedToWrite = 0
    }
    
    @inlinable
    func pass(to subject: PassthroughSubject<Self, Never>) {
        subject.send(self)
    }
    
    @inlinable
    func task(_ value: URLSessionDownloadTask) -> Self {
        SessionTaskState(task: value, reciveBytes: reciveBytes, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
    }
    
    @inlinable
    func reciveBytes(_ value: Int64) -> Self {
        SessionTaskState(task: task, reciveBytes: value, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
    }
    
    @inlinable
    func totalBytesWritten(_ value: Int64) -> Self {
        SessionTaskState(task: task, reciveBytes: reciveBytes, totalBytesWritten: value, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
    }
    
    @inlinable
    func totalBytesExpectedToWrite(_ value: Int64) -> Self {
        SessionTaskState(task: task, reciveBytes: reciveBytes, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: value)
    }
}

public struct DownloadURLError: Error {
    public let task: URLSessionTask
    public let error: Error
}

//public enum DataObject {
//    case file(URL)
//    case raw(Data)
//}

public struct SessionComplete {
    public let task: URLSessionTask
    public let data: URL
    
    @inlinable
    func pass(to subject: PassthroughSubject<Result<SessionComplete, DownloadURLError>, Never>) {
        subject.send(.success(self))
    }
}
//
//public struct SessionErrorNotification {
//    public let task: URLSessionTask
//    public let error: Error
//
//    @inlinable
//    func pass(to subject: PassthroughSubject<Self, Never>) {
//        subject.send(self)
//    }
//}

class URLSessionDelegator: NSObject, URLSessionDownloadDelegate {
    let downloadTaskUpdate = PassthroughSubject<SessionTaskState, Never>()
    let downloadTaskCompletion = PassthroughSubject<Result<SessionComplete, DownloadURLError>, Never>()
//    let failedTaskCompletion = PassthroughSubject<SessionErrorNotification, Never>()
    
    #if DEBUG
    static var debugFlag = true
    #endif
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let filename = UUID().uuidString
        let cachedURL = FileManager.default.temporaryDirectory
        let url = cachedURL.appendingPathComponent(filename)
        
        do {
            try FileManager.default.moveItem(at: location, to: url)
#if DEBUG
            logger.info("move tmp file to \(url)")
#endif
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
