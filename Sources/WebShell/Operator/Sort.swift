//
//  File.swift
//  
//
//  Created by john on 2023/9/21.
//

import Foundation
import Durex

public enum SortOrder {
    case reverse
}

public struct Sort<T: Dirtyware>: Dirtyware where T.Input == KeyStore {
    public typealias Input = T.Input
    public typealias Output = T.Output
    
    public let order: SortOrder
    public let task: T
    public let key: KeyStore.Key
    
    public init(_ order: SortOrder, key: KeyStore.Key = .output, task: T) {
        self.order = order
        self.task = task
        self.key = key
    }

    public func execute(for inputValue: Input) async throws -> Output {
        let value = try await task.execute(for: inputValue)
        if let output: any Sequence = inputValue.value(forKey: key) {
            switch order {
            case .reverse:
                shellLogger.info("reversed sequence [\(key)]")
                inputValue.assign(output.reversed(), forKey: key)
            }
        }   else    {
            shellLogger.info("no sequence found in \(key)")
        }
        return value
    }
}

extension Dirtyware {
    /// reversed output value if it's `Sequence`
    public func sort(_ order: SortOrder) -> Sort<Self> where Input == KeyStore {
        .init(order, key: .output, task: self)
    }
}
