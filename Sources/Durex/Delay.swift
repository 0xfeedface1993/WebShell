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

public struct Delay<T, V>: Condom {
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

public struct DelayDirtyware<T: Dirtyware, V: Dirtyware>: Dirtyware {
    public typealias Input = T.Input
    public typealias Output = V.Output
    
    public let out: V.Output
    
    init(_ item: T.Input, out: V.Output) {
        self.out = out
    }
    
    init(_ out: V.Output) {
        self.out = out
    }
    
    public func execute(for inputValue: Input) async throws -> Output {
        if #available(macOS 13.0, *) {
            try await Task.sleep(for: .seconds(2))
        } else {
            // Fallback on earlier versions
            sleep(2000)
        }
        return out
    }
}
