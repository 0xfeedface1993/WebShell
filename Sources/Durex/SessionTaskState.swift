//
//  File.swift
//  
//
//  Created by john on 2023/9/5.
//

import Foundation

#if COMBINE_LINUX && canImport(CombineX)
import CombineX
#else
import Combine
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct SessionTaskState: Sendable {
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
    
    func newsState() -> TaskNews.State {
        let progress = Progress(totalUnitCount: totalBytesExpectedToWrite)
        progress.completedUnitCount = totalBytesWritten
        return .init(progress: progress, filename: task.response?.suggestedFilename, identifier: task.taskIdentifier)
    }
}
