//
//  File.swift
//  
//
//  Created by john on 2023/5/1.
//

import Foundation
import Combine

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
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        SessionComplete(task: downloadTask, data: location)
            .pass(to: downloadTaskCompletion)
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
