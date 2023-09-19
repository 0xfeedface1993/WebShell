//
//  File.swift
//  
//
//  Created by john on 2023/9/12.
//

import Foundation
import Durex

public struct LoginFormhash: SessionableDirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public var key: AnyHashable
    public var configures: AsyncURLSessionConfiguration
    
    public init(_ configures: AsyncURLSessionConfiguration, key: AnyHashable = "default") {
        self.key = key
        self.configures = configures
    }
    
    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        try await URLRequestPageReader(.output, configures: configures, key: key)
            .join(FindStringInFile(.htmlFile, forKey: .formhash, finder: .formhash))
            .execute(for: inputValue)
    }
    
    public func sessionKey(_ value: AnyHashable) -> LoginFormhash {
        .init(configures, key: value)
    }
}

