//
//  File.swift
//  
//
//  Created by john on 2023/5/2.
//

import Foundation

@available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
public typealias Lock = os_unfair_lock_t

@available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
extension UnsafeMutablePointer where Pointee == os_unfair_lock_s {
    public init() {
        let l = UnsafeMutablePointer.allocate(capacity: 1)
        l.initialize(to: os_unfair_lock())
        self = l
    }
    
    public func cleanupLock() {
        deinitialize(count: 1)
        deallocate()
    }
    
    public func lock() {
        os_unfair_lock_lock(self)
    }
    
    public func tryLock() -> Bool {
        let result = os_unfair_lock_trylock(self)
        return result
    }
    
    public func unlock() {
        os_unfair_lock_unlock(self)
    }
}
