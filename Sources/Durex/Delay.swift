//
//  File.swift
//  
//
//  Created by john on 2023/2/15.
//

import Foundation

#if COMBINE_LINUX && canImport(CombineX)
import CombineX
#else
import Combine
#endif

public enum VoidValue: ContextValue {
    case nop
    
    public var valueDescription: String {
        "nop"
    }
}

public struct Delay<T, V>: Condom where T: Sendable, V: Sendable {
    public typealias Input = ValueBox<T>
    public typealias Output = ValueBox<V>
    
    public let out: V
    
    init(_ item: T, out: V) {
        self.out = out
    }
    
    init(_ out: V) {
        self.out = out
    }
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        empty()
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Just(.empty)
            .setFailureType(to: Error.self)
            .delay(for: 2, tolerance: nil, scheduler: RunLoop.current.scheduler)
            .eraseToAnyPublisher()
    }
}
