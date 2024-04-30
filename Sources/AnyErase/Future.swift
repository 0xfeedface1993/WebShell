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
    public convenience init(operation: @escaping () async throws -> Output) {
        self.init { promise in
            Task.detached {
                do {
                    let output = try await operation()
                    promise(.success(output))
                } catch {
                    promise(.failure(error))
                }
            }
        }
    }
}

extension Future where Failure == Never {
    public convenience init(operation: @escaping () async -> Output) {
        self.init { promise in
            Task.detached {
                let output = await operation()
                promise(.success(output))
            }
        }
    }
}
