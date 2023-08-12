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
public typealias RunLoopSchduler = CXWrappers.RunLoop
#else
import Combine
public typealias RunLoopSchduler = RunLoop
#endif

public struct RunLoopScheduler {
    let _queue: RunLoop
    
    public init(_ queue: RunLoop) {
        self._queue = queue
    }
    
    public var queue: RunLoopSchduler {
        #if COMBINE_LINUX && canImport(CombineX)
        _queue.cx
        #else
        _queue
        #endif
    }
}

extension RunLoop {
    @inlinable
    public var scheduler: RunLoopSchduler {
        RunLoopScheduler(self).queue
    }
}

