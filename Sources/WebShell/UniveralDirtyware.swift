//
//  File.swift
//  WebShell
//
//  Created by york on 2025/8/31.
//

import Foundation
import Durex

public protocol UniversalDirtyware: Dirtyware where Input == KeyStore, Output == KeyStore {
    
}

extension AnyDirtyware: UniversalDirtyware where Input == Output, Input == KeyStore, Output == KeyStore {
    
}
