//
//  File.swift
//  
//
//  Created by Peter on 2023/8/11.
//

import Foundation
#if COMBINE_LINUX && canImport(CombineX)
import CombineX
import CXFoundation
public typealias QueueSchduler = CXWrappers.DispatchQueue
#else
import Combine
public typealias QueueSchduler = DispatchQueue
#endif

public struct QueueScheduler {
    let _queue: DispatchQueue
    
    public init(_ queue: DispatchQueue) {
        self._queue = queue
    }
    
    public var queue: QueueSchduler {
        #if COMBINE_LINUX && canImport(CombineX)
        _queue.cx
        #else
        _queue
        #endif
    }
}

extension DispatchQueue {
    @inlinable
    public var scheduler: QueueSchduler {
        QueueScheduler(self).queue
    }
}
