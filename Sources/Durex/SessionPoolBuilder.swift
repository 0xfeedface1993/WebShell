//
//  File.swift
//  
//
//  Created by Peter on 2023/2/22.
//

import Foundation
#if COMBINE_LINUX && canImport(CombineX)
import CombineX
import CXFoundation
#else
import Combine
#endif
#if canImport(AnyErase)
import AnyErase
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public typealias SessionContext = CustomURLSession

public struct SessionPoolBuilder<Context: SessionContext, Key: Hashable> {
    let context: Context?
    let key: Key?
    
    public init(_ context: Context?, key: Key? = nil) {
        self.context = context
        self.key = key
    }
    
    func key(_ value: Key) -> Self {
        SessionPoolBuilder(context, key: value)
    }
    
    func context(_ value: Context) -> Self {
        SessionPoolBuilder(value, key: key)
    }
    
    func _store(_ value: Context?, forKey: Key?) {
        guard let context = value, let key = forKey else {
            return
        }
        _ = Sessions(key).store(context)
    }
    
    public func store() -> AnyPublisher<Context, Error> {
        guard let context = context, let key = key else {
            return Fail(error: SessionError(pool: nil, context: context))
                .eraseToAnyPublisher()
        }
        return AnyValue((context, key))
            .receive(on: DispatchQueue.main.scheduler)
            .follow(_store(_:forKey:))
            .map(\.0)
            .eraseToAnyPublisher()
    }
}
