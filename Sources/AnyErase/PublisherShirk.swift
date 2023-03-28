//
//  File.swift
//  
//
//  Created by john on 2023/3/10.
//

import Combine

public struct PublishersShrik<Value, Failure> where Failure: Error {
    let publishers: [AnyPublisher<Value, Failure>]
    
    public init(_ publishers: [AnyPublisher<Value, Failure>]) {
        self.publishers = publishers
    }
    
    public func merge() -> AnyPublisher<Value, Failure> {
        guard publishers.count > 0 else {
            return Empty().eraseToAnyPublisher()
        }
        var publisher = publishers.first!
        
        if publishers.count > 1 {
            publisher = publishers.dropFirst()
                .reduce(publisher) {
                    $1.merge(with: $0).eraseToAnyPublisher()
                }
                .eraseToAnyPublisher()
        }
        
        return publisher
    }
    
    /// 多个异步结果合并成一个数组
    public func zip() -> AnyPublisher<[Value], Failure> {
        guard publishers.count > 0 else {
            return Empty().eraseToAnyPublisher()
        }
        
        return Publishers.MergeMany(publishers)
            .collect()
            .eraseToAnyPublisher()
    }
}
