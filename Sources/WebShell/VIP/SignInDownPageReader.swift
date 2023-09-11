//
//  File.swift
//  
//
//  Created by john on 2023/9/12.
//

import Foundation
import Durex

public struct SignInDownPageReader: SessionableDirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public var key: AnyHashable
    public var configures: AsyncURLSessionConfiguration
    
    init(_ configures: AsyncURLSessionConfiguration, key: AnyHashable) {
        self.key = key
        self.configures = configures
    }
    
    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        let request = try inputValue.request(.lastOutput)
        let sign = try await FindStringInDomSearch(FileIDMatch.sign, configures: configures, key: key).execute(for: request)
        return inputValue
            .assign(sign, forKey: .sign)
            .assign(sign, forKey: .lastOutput)
            .assign(request, forKey: .lastRequest)
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        .init(configures, key: value)
    }
}
