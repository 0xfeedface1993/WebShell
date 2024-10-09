//
//  File.swift
//  
//
//  Created by john on 2023/2/19.
//

import Foundation
#if COMBINE_LINUX && canImport(CombineX)
import CombineX
#else
import Combine
#endif

public struct AnyCondom<Input, Output>: Condom where Input: ContextValue, Output: ContextValue {
    @usableFromInline
    internal let makePublisher: @Sendable (Input) -> AnyPublisher<Output, Error>
    @usableFromInline
    internal let makeEmptyPublisher: @Sendable () -> AnyPublisher<Output, Error>
    
    @inlinable
    init<T>(_ condom: T) where T: Condom, T.Input == Input, Output == T.Output {
        self.makePublisher = condom.publisher(for:)
        self.makeEmptyPublisher = condom.empty
    }
    
    @inlinable
    init<T, V>(_ first: T, last: V) where T: Condom, V: Condom, T.Input == Input, T.Output == V.Input, V.Output == Output {
        self.makePublisher = { value in
            first.publisher(for: value)
                .flatMap(last.publisher(for:))
                .eraseToAnyPublisher()
        }
        self.makeEmptyPublisher = {
            first.empty()
                .map({ _ in () })
                .flatMap(last.empty)
                .eraseToAnyPublisher()
        }
    }
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        makePublisher(inputValue)
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        makeEmptyPublisher()
    }
    
    
}

public struct AnyDirtyware<Input, Output>: Dirtyware where Input: ContextValue, Output: ContextValue {
    @usableFromInline
    internal let makePublisher: @Sendable (Input) async throws -> Output
    
    @inlinable
    init<T>(_ condom: T) where T: Dirtyware, T.Input == Input, Output == T.Output {
        self.makePublisher = condom.execute(for:)
    }
    
    @inlinable
    init<T, V>(_ first: T, last: V) where T: Dirtyware, V: Dirtyware, T.Input == Input, T.Output == V.Input, V.Output == Output {
        self.makePublisher = { value in
            let result = try await first.execute(for: value)
            let next = try await last.execute(for: result)
            return next
        }
    }
    
    public func execute(for inputValue: Input) async throws -> Output {
        try await makePublisher(inputValue)
    }
}
