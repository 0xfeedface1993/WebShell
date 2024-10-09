//
//  File.swift
//  
//
//  Created by john on 2023/9/5.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct DownloadSessionError: Error, Sendable {
    let originError: Error
    let task: URLSessionTask
    let date = Date()
}

public enum DownloadSessionRawError: Error, Sendable {
    case invalidResponse
    case unknown
}

public struct DownloadURLError: Error, Sendable {
    public let task: URLSessionTask
    public let error: Error
}

public struct UpdateFailure: Equatable, Sendable, Hashable {
    public static func == (lhs: UpdateFailure, rhs: UpdateFailure) -> Bool {
        lhs.identifier == rhs.identifier
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
    
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

public enum SessionKeyError: Error, Sendable {
    case noValidKey(TaskIdentifiable.Key)
}
