//
//  File.swift
//  
//
//  Created by john on 2023/2/19.
//

import Foundation
import Combine

public struct AnyCondom<Input, Output>: Condom where Input: ContextValue, Output: ContextValue {
    @usableFromInline
    internal let makePublisher: (Input) -> AnyPublisher<Output, Error>
    @usableFromInline
    internal let makeEmptyPublisher: () -> AnyPublisher<Output, Error>
    
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
