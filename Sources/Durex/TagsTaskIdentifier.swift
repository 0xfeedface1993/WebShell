//
//  File.swift
//  
//
//  Created by john on 2023/9/5.
//

import Foundation

public protocol TaskIdentifiable {
    typealias Value = AnyHashable
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
