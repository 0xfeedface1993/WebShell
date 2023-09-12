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
    
    public let action: (Value) -> Void
    
    public init(action: @escaping (Value) -> Void) {
        self.action = action
    }

    public func execute(for inputValue: Value) async throws -> Value {
        action(inputValue)
        return inputValue
    }
}
