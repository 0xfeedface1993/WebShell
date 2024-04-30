//
//  File.swift
//  
//
//  Created by john on 2023/9/12.
//

import Foundation
import Durex

public struct FollowAction<Value>: Dirtyware where Value: ContextValue {
    public typealias Input = Value
    public typealias Output = Value
    
    public let action: (Value) async throws -> Void
    
    public init(action: @escaping (Value) async throws -> Void) {
        self.action = action
    }

    public func execute(for inputValue: Value) async throws -> Value {
        try await action(inputValue)
        return inputValue
    }
}

extension Dirtyware {
    public func map(_ action: @escaping (Self.Output) async throws -> Void) -> AnyDirtyware<Self.Input, Self.Output> {
        join(FollowAction(action: action))
    }
}
