//
//  File.swift
//  
//
//  Created by john on 2023/9/5.
//

import Foundation

#if COMBINE_LINUX && canImport(CombineX)
import CombineX
#else
import Combine
#endif

extension Future where Failure == Error {
    public convenience init(@_implicitSelfCapture operation: @Sendable @escaping () async throws -> Output) {
        self.init { promise in
            nonisolated(unsafe) let promise = promise
            let action: @Sendable () async -> Void = {
                do {
                    let output = try await operation()
                    promise(.success(output))
                } catch {
                    promise(.failure(error))
                }
            }
            Task(operation: action)
        }
    }
}

extension Future where Failure == Never {
    public convenience init(@_implicitSelfCapture operation: @Sendable @escaping () async -> Output) {
        self.init { promise in
            nonisolated(unsafe) let promise = promise
            let action: @Sendable () async -> Void = {
                let output = await operation()
                promise(.success(output))
            }
            Task(operation: action)
        }
    }
}
