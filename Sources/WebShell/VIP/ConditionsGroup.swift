//
//  File.swift
//  
//
//  Created by john on 2023/9/19.
//

import Foundation
import Durex

public struct ConditionsGroup<T: Dirtyware, V: Dirtyware>: Dirtyware where T.Input == V.Input, T.Output == V.Output {
    public typealias Input = T.Input
    public typealias Output = T.Output
    
    public let first: T
    public let last: V
    
    public init(_ first: T, _ last: V) {
        self.first = first
        self.last = last
    }

    public func execute(for inputValue: T.Input) async throws -> T.Output {
        do {
            return try await first.execute(for: inputValue)
        } catch {
            return try await last.execute(for: inputValue)
        }
    }
    
    public func append<K: Dirtyware>(_ next: K) -> ConditionsGroup<Self, K> where T.Input == K.Input, T.Output == K.Output, V.Input == K.Input, V.Output == K.Output {
        .init(self, next)
    }
    
    public func eraseToAnyGroup<X: ContextValue, Y: ContextValue>() -> AnyConditionsGroup<X, Y> where T.Input == X, T.Output == Y {
        .init(self)
    }
}

public struct AnyConditionsGroup<X: ContextValue, Y: ContextValue>: Dirtyware {
    public typealias Input = X
    public typealias Output = Y
    
    let group: any Dirtyware<Output, Input>
    
    init<J: Dirtyware, K: Dirtyware>(_ group: ConditionsGroup<J, K>) where J.Input == K.Input, J.Output == K.Output, J.Input == X, J.Output == Y {
        self.group = group
    }
    
    public func execute(for inputValue: X) async throws -> Y {
        try await group.execute(for: inputValue)
    }
    
    public func append<K: Dirtyware>(_ next: K) -> AnyConditionsGroup<X, Y> where X == K.Input, X == K.Output, Y == K.Input, Y == K.Output {
        .init(.init(self, next))
    }
    
    public func eraseToAnyGroup() -> AnyConditionsGroup<X, Y> {
        self
    }
}

public struct FlatMap<T: ContextValue, V: ContextValue>: Dirtyware {
    public typealias Input = T
    public typealias Output = V
    
    public let tranform: (T) -> any Dirtyware<Output, Input>

    public func execute(for inputValue: T) async throws -> V {
        try await tranform(inputValue).execute(for: inputValue)
    }
}
