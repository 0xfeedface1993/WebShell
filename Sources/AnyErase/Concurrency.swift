//
//  File.swift
//  
//
//  Created by john on 2023/8/18.
//

import Foundation
import Logging

internal let logger = Logger(label: "com.webshell.anyerase")

#if COMBINE_LINUX && canImport(CombineX)
import CombineX

struct CheckedContinuationSlide<T: Publisher> {
    let publisher: T
    
    init(_ publisher: T) {
        self.publisher = publisher
    }
    
    func resume(in continuation: UnsafeContinuation<T.Output, Error>) -> AnyCancellable {
        var flag = true
        let type = "\(publisher.self)"
        let cancellable = publisher.sink { completion in
            switch completion {
            case .finished:
                if flag {
                    continuation.resume(throwing: CocoaError.error(.featureUnsupported))
                }
                break
            case .failure(let error):
                continuation.resume(throwing: error)
            }
        } receiveValue: { value in
            flag = false
            continuation.resume(returning: value)
        }
        logger.info("bridge CombineX publisher \(type) to Concurrency Swift hold on \(String(describing: cancellable)).")
        return cancellable
    }
}

extension Publisher {
    /// Bridge to Swift Concurrency
    public var asyncValue: Output {
        get async throws {
            let slide = CheckedContinuationSlide(self)
            // Swift Concurrency release local variables until block value return or execute complete.
            var cancellable: AnyCancellable?
            let result = try await withCheckedThrowingContinuation({ continuation in
                cancellable = slide.resume(in: continuation)
            })
            logger.info("bridge CombineX publisher \(self) dismiss.")
            return result
        }
    }
}
#else

import Combine

extension Publisher {
    /// Bridge to Swift Concurrency
    @inlinable
    @available(macOS 12, iOS 13, *)
    public var asyncValue: Output  {
        get async throws {
            for try await i in self.values {
                return i
            }
            throw CocoaError.error(.featureUnsupported)
        }
    }
}

#endif

