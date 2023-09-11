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
    
    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        let request = try inputValue.request(.lastOutput)
        let html = try await FindStringInDomSearch(FileIDMatch.formhash, configures: configures, key: key).execute(for: request)
        return inputValue
            .assign(request, forKey: .lastRequest)
            .assign(html, forKey: .lastOutput)
    }
    
    public func sessionKey(_ value: AnyHashable) -> LoginFormhash {
        .init(key: value, configures: configures)
    }
}
