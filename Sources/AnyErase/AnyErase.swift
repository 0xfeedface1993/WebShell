//
//  File.swift
//  
//
//  Created by Peter on 2023/3/2.
//

#if COMBINE_LINUX && canImport(CombineX)
import CombineX
#else
import Combine
#endif

extension Publisher {
    /// map中执行action闭包并返回原对象
    /// - Parameter action: 需要跟随Map闭包执行的闭包
    /// - Returns: map类型
    public func follow(_ transform: @escaping (Output) -> Void) -> Publishers.Follow<Self> {
        .init(upstream: self, transform: transform)
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Publishers {
    public struct Follow<Upstream> : Publisher where Upstream : Publisher {
        public typealias Failure = Upstream.Failure
        public typealias Output = Upstream.Output
        
        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The closure that transforms elements from the upstream publisher.
        public let transform: (Upstream.Output) -> Void

        /// Creates a publisher that transforms all elements from the upstream publisher with a provided closure.
        /// - Parameters:
        ///   - upstream: The publisher from which this publisher receives elements.
        ///   - transform: The closure that transforms elements from the upstream publisher.
        public init(upstream: Upstream, transform: @escaping (Upstream.Output) -> Void) {
            self.upstream = upstream
            self.transform = transform
        }

        /// Attaches the specified subscriber to this publisher.
        ///
        /// Implementations of ``Publisher`` must implement this method.
        ///
        /// The provided implementation of ``Publisher/subscribe(_:)-4u8kn``calls this method.
        ///
        /// - Parameter subscriber: The subscriber to attach to this ``Publisher``, after which it can receive values.
        public func receive<S>(subscriber: S) where Output == S.Input, S : Subscriber, Upstream.Failure == S.Failure {
            upstream.subscribe(Inner(downstream: subscriber, callback: transform))
        }
    }
}

extension Publishers.Follow {
    private struct Inner<Downstream: Subscriber>: Subscriber where Downstream.Input == Upstream.Output, Upstream.Failure == Downstream.Failure {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure
        private let downstream: Downstream
        private let callback: (Input) -> Void
        let combineIdentifier = CombineIdentifier()
        
        init(downstream: Downstream, callback: @escaping (Input) -> Void) {
            self.downstream = downstream
            self.callback = callback
        }
        
        func receive(subscription: Subscription) {
            downstream.receive(subscription: subscription)
        }
        
        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            callback(input)
            return downstream.receive(input)
        }
        
        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            downstream.receive(completion: completion)
        }
    }
}
