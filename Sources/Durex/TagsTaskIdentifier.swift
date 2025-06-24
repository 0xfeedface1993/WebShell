//
//  File.swift
//  
//
//  Created by john on 2023/9/5.
//

import Foundation

public enum TaskTag: Hashable, Equatable, Sendable, CustomStringConvertible {
    case uid(UUID)
    case string(String)
    case int(Int)
    case int64(Int64)
    
    public var description: String {
        switch self {
        case .uid(let id):
            return "{uuid: \(id)}"
        case .string(let string):
            return "{string: \(string)}"
        case .int(let int):
            return "{int: \(int)}"
        case .int64(let int64):
            return "{int64: \(int64)}"
        }
    }
}

public protocol TaskIdentifiable: Sendable {
    typealias Value = TaskTag
    typealias Key = Int
    
    func tag(for taskIdentifier: Key) async -> Value?
    func taskIdentifier(for tag: Value) async -> Key?
    func set(_ tag: Value, for taskIdentifier: Key) async
    func remove(taskIdentifier: Key) async
    func remove(tag: Value) async
}

actor TagsTaskIdentifier: TaskIdentifiable {
    private var cached = [Key: Value]()
    
    func tag(for taskIdentifier: Key) -> Value? {
        cached[taskIdentifier]
    }
    
    func taskIdentifier(for tag: Value) -> Key? {
        cached.first(where: { $0.value == tag })?.key
    }
    
    func set(_ tag: Value, for taskIdentifier: Key) {
        cached.filter({ $0.value == tag })
            .forEach {
                cached.removeValue(forKey: $0.key)
            }
        cached[taskIdentifier] = tag
    }
    
    func remove(taskIdentifier: Key) {
        guard let tag = tag(for: taskIdentifier) else {
            logger.debug("no tag with taskIdentifier [\(taskIdentifier)]")
            return
        }
        logger.debug("remve taskIdentifier [\(taskIdentifier)] and tag [\(tag)]")
        cached.removeValue(forKey: taskIdentifier)
    }
    
    func remove(tag: Value) {
        guard let taskIdentifier = taskIdentifier(for: tag) else {
            logger.debug("no taskIdentifier with tag [\(tag)]")
            return
        }
        logger.debug("remve taskIdentifier [\(taskIdentifier)] and tag [\(tag)]")
        cached.removeValue(forKey: taskIdentifier)
    }
}
