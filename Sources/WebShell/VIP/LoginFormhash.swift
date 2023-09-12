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
        let request = try inputValue.request(.output)
        let html = try await FindStringInDomSearch(FileIDMatch.formhash, configures: configures, key: key).execute(for: request)
        return inputValue
            .assign(html, forKey: .formhash)
            .assign(request, forKey: .lastRequest)
            .assign(html, forKey: .output)
    }
    
    public func sessionKey(_ value: AnyHashable) -> LoginFormhash {
        .init(configures, key: value)
    }
}
