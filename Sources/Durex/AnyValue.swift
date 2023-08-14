//
//  File.swift
//  
//
//  Created by john on 2023/2/21.
//

import Foundation

#if COMBINE_LINUX && canImport(CombineX)
import CombineX
#else
import Combine
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct AnyValue<T>: Publisher {
    public typealias Output = T
    public typealias Failure = Error
    
    private let raw: T
    
    public init(_ raw: T) {
        self.raw = raw
    }
    
    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, T == S.Input {
        subscriber.receive(subscription: Inner(raw, downstram: subscriber))
    }
}

extension AnyValue {
    internal final class Inner<Downstream: Subscriber>: Subscription where Downstream.Input == Output {
        private var downstram: Downstream?
        private let raw: T
        
        init(_ raw: Output, downstram: Downstream) {
            self.raw = raw
            self.downstram = downstram
        }
        
        func request(_ demand: Subscribers.Demand) {
            guard let downstram = downstram else { return }
            _ = downstram.receive(raw)
            downstram.receive(completion: .finished)
        }
        
        func cancel() {
            downstram = nil
        }
    }
}


extension ValueBox where T == URLRequest {
    public init(_ url: URL) {
        self = .item(URLRequest(url: url))
    }
}
