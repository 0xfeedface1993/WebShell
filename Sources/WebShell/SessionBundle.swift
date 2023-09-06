//
//  File.swift
//  
//
//  Created by john on 2023/9/6.
//

import Foundation

public struct SessionBundle {
    public let sessionKey: AnyHashable
    
    public init(_ sessionKey: AnyHashable) {
        self.sessionKey = sessionKey
    }
}
