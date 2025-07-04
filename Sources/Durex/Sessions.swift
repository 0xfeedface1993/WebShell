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
enum Sessions: Hashable, Equatable, Sendable {
    case `default`
    case key(SessionKey)
    
    init(_ hashValue: SessionKey) {
        self = .key(hashValue)
    }
}
