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
}
