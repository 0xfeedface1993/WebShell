//
//  File.swift
//  
//
//  Created by john on 2023/9/5.
//

import Foundation

#if COMBINE_LINUX && canImport(CombineX)
import CombineX
import CXFoundation
#else
import Combine
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if canImport(AnyErase)
import AnyErase
#endif

@usableFromInline
enum Sessions: Hashable {
    case `default`
    case key(any Hashable)
    
    fileprivate static var cache = [Sessions: SessionPoolState]()
    
    @usableFromInline
    static func == (lhs: Sessions, rhs: Sessions) -> Bool {
        lhs.hashValue == rhs.hashValue
    }
    
    @usableFromInline
    func hash(into hasher: inout Hasher) {
        switch self {
        case .default:
            hasher.combine("default")
        case .key(let hashable):
            hasher.combine(hashable)
        }
    }
    
    init(_ hash: any Hashable) {
        self = .key(hash)
    }
    
    internal func store(_ context: SessionContext) -> SessionContext {
        let value = Sessions.cache[self] ?? SessionPoolState(context)
        value.context = context
        Sessions.cache[self] = value
        return context
    }
    
    internal func clear() {
        Sessions.cache.removeValue(forKey: self)
    }
    
    func take() throws -> SessionPoolState {
        switch self {
        case .default:
            throw DurexError.nilSession
        case .key(_):
            guard let value = Sessions.cache[self] else {
                throw DurexError.nilSession
            }
            return value
        }
    }
}
