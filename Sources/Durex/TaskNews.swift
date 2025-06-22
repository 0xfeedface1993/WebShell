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

public enum TaskNews: Equatable, Sendable, Hashable, CustomStringConvertible {
    case state(State)
    case file(FileStone)
    case error(UpdateFailure)
    
    public struct State: Equatable, Sendable, Hashable {
        public let progress: Progress
        public let filename: String?
        public let identifier: Int
        
        public static let none = State(progress: .init(totalUnitCount: 0), filename: nil, identifier: 0)
        
        init(progress: Progress, filename: String?, identifier: Int) {
            self.progress = progress
            self.filename = filename
            self.identifier = identifier
        }
        
        public func tag(_ value: Int) -> State {
            State(progress: progress, filename: filename, identifier: value)
        }
    }
    
    public struct FileStone: Equatable, Sendable, Hashable {
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
    
    public var isCompleted: Bool {
        switch self {
        case .file(_):
            return true
        case .state(_):
            return false
        case .error(_):
            return true
        }
    }
    
    public var description: String {
        switch self {
        case .state(let state):
            return "progress \(state.progress.fractionCompleted)"
        case .file(let fileStone):
            return "save at \(fileStone.url)"
        case .error(let updateFailure):
            return "\(updateFailure)"
        }
    }
}

public struct UpdateNews: Sendable {
    public let value: TaskNews
    public let tagHashValue: Int
    
    public init(value: TaskNews, tagHashValue: Int) {
        self.value = value
        self.tagHashValue = tagHashValue
    }
}

public struct AsyncUpdateNews: Sendable {
    public typealias TagValue = TaskTag
    
    public let value: TaskNews
    private let tag: TagValue
    
    public init(value: TaskNews, tag: TagValue) {
        self.value = value
        self.tag = tag
    }
    
    public func tagValue() -> TagValue { tag }
}
