//
//  File.swift
//  
//
//  Created by john on 2023/9/6.
//

import Foundation
import Durex

public struct SessionBundle {
    public let sessionKey: AnyHashable
    public let congifures: AsyncURLSessionConfiguration
    
    public init(sessionKey: AnyHashable, congifures: AsyncURLSessionConfiguration) {
        self.sessionKey = sessionKey
        self.congifures = congifures
    }
    
    public init(sessionKey: AnyHashable) {
        self.sessionKey = sessionKey
        self.congifures = .shared
    }
    
    func sessionKey(_ value: AnyHashable) -> Self {
        .init(sessionKey: value, congifures: congifures)
    }
    
    func congifures(_ value: AsyncURLSessionConfiguration) -> Self {
        .init(sessionKey: sessionKey, congifures: value)
    }
}
