//
//  File.swift
//  
//
//  Created by john on 2023/9/8.
//

import Foundation

#if canImport(Durex)
import Durex
#endif

#if COMBINE_LINUX && canImport(CombineX)
import CombineX
#else
import Combine
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct FutureAnyCondom<OutputValue: ContextValue, InputValue: ContextValue>: Condom {
    public typealias Output = OutputValue
    public typealias Input = InputValue
    
    public let operation: (Input) async throws -> Output
    
    public init(_ operation: @escaping (Input) async throws -> Output) {
        self.operation = operation
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        Future {
            try await operation(inputValue)
        }
        .eraseToAnyPublisher()
    }
}

extension Dirtyware {
    func condom() -> AnyCondom<Input, Output> {
        FutureAnyCondom { value in
            try await execute(for: value)
        }
        .eraseToAnyCondom()
    }
}
