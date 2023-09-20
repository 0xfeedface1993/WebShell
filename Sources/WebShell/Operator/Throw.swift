//
//  File.swift
//  
//
//  Created by john on 2023/9/21.
//

import Foundation
import Durex

public struct Throw<T: Dirtyware>: Dirtyware {
    public typealias Input = T.Input
    public typealias Output = T.Output
    
    public let task: T
    public let error: (Input) -> Error
    
    public init(_ task: T, error: @escaping (Input) -> Error) {
        self.task = task
        self.error = error
    }

    public func execute(for inputValue: Input) async throws -> Output {
        let value = try await task.execute(for: inputValue)
        throw error(inputValue)
    }
}

extension Dirtyware {
    /// 无论如何都会抛出错误，
    /// 1. 任务执行成功，则抛出自定义错误
    /// 2. 任务执行失败，继续向上抛出错误
    public func `throw`(_ error: @escaping (Input) -> Error) -> Throw<Self> {
        Throw(self, error: error)
    }
}
