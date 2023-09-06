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
