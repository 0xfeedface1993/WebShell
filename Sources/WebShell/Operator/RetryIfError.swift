//
//  File.swift
//  
//
//  Created by john on 2023/9/20.
//

import Foundation
import Durex

public struct RetryIfError<T: Dirtyware>: Dirtyware {
    public typealias Input = T.Input
    public typealias Output = T.Output
    
    public let times: Int
    public let task: T
    
    public init(_ times: Int, task: T) {
        self.times = max(1, times)
        self.task = task
    }

    public func execute(for inputValue: Input) async throws -> Output {
        var failed: Error?
        for i in 0..<times {
            do {
                return try await task.execute(for: inputValue)
            } catch {
                shellLogger.error("retry failed at \(i + 1) times, error \(error)")
                failed = error
            }
        }
        throw failed ?? LoginError.unknown
    }
}

extension Dirtyware {
    /// retry task if error throw
    public func retry(_ times: Int) -> RetryIfError<Self> {
        .init(times, task: self)
    }
}
