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

public enum DownloadSessionRawError: Error {
    case invalidResponse
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
    
    func newsState() -> TaskNews.State {
        let progress = Progress(totalUnitCount: totalBytesExpectedToWrite)
        progress.completedUnitCount = totalBytesWritten
        return .init(progress: progress, filename: task.response?.suggestedFilename, identifier: task.taskIdentifier)
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
    
    func fileStone() -> TaskNews {
        guard let response = task.response else {
            return .error(.init(error: DownloadSessionError(originError: DownloadSessionRawError.invalidResponse, task: task), identifier: task.taskIdentifier))
        }
        return TaskNews.file(.init(url: data, response: response, identifier: task.taskIdentifier))
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

public struct UpdateFailure {
    public enum NoneError: Error {
        case none
    }
    public let error: Error
    public let identifier: Int
    
    public init(error: Error, identifier: Int) {
        self.error = error
        self.identifier = identifier
    }
    
    public static let none = UpdateFailure(error: NoneError.none, identifier: 0)
    
    public func tag(_ value: Int) -> Self {
        .init(error: error, identifier: value)
    }
}

public struct UpdateNews {
    public let value: TaskNews
    public let tagHashValue: Int
    
    public init(value: TaskNews, tagHashValue: Int) {
        self.value = value
        self.tagHashValue = tagHashValue
    }
}

public enum TaskNews {
    case state(State)
    case file(FileStone)
    case error(UpdateFailure)
    
    public struct State: Equatable {
        public let progress: Progress
        public let filename: String?
        public let identifier: Int
        
        public static let none = State(progress: .init(), filename: nil, identifier: 0)
        
        init(progress: Progress, filename: String?, identifier: Int) {
            self.progress = progress
            self.filename = filename
            self.identifier = identifier
        }
        
        public func tag(_ value: Int) -> State {
            State(progress: progress, filename: filename, identifier: value)
        }
    }
    
    public struct FileStone: Equatable {
        public let url: URL
        public let response: URLResponse
        public let identifier: Int
        
        public func tag(_ value: Int) -> Self {
            .init(url: url, response: response, identifier: value)
        }
    }
    
    public var identifier: Int {
        switch self {
        case .file(let value):
            return value.identifier
        case .state(let value):
            return value.identifier
        case .error(let error):
            return error.identifier
        }
    }
}

class URLSessionDelegator: NSObject, URLSessionDownloadDelegate {
    private let downloadTaskUpdate = PassthroughSubject<SessionTaskState, Never>()
    private let downloadTaskCompletion = PassthroughSubject<Result<SessionComplete, DownloadURLError>, Never>()
    /// 状态更新，可监听此Subject进行下载进度、下载完成、下载失败三种类型类型事件更新
    let statePassthroughSubject = PassthroughSubject<TaskNews, Never>()
    private let stateCancellable: AnyCancellable
    
    #if DEBUG
    static var debugFlag = true
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
