//
//  File.swift
//  
//
//  Created by john on 2023/9/6.
//

import Foundation
import Durex

public struct SessionBundle: Sendable {
    public let sessionKey: SessionKey
    public let congifures: AsyncURLSessionConfiguration
    
    public init(sessionKey: SessionKey, congifures: AsyncURLSessionConfiguration) {
        self.sessionKey = sessionKey
        self.congifures = congifures
    }
    
    public init(sessionKey: SessionKey) {
        self.sessionKey = sessionKey
        self.congifures = .shared
    }
    
    func sessionKey(_ value: SessionKey) -> Self {
        .init(sessionKey: value, congifures: congifures)
    }
    
    func congifures(_ value: AsyncURLSessionConfiguration) -> Self {
        .init(sessionKey: sessionKey, congifures: value)
    }
}
