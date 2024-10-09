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
    
    public let key: SessionKey
    public var configures: AsyncURLSessionConfiguration
    
    public init(_ configures: AsyncURLSessionConfiguration, key: SessionKey) {
        self.key = key
        self.configures = configures
    }
    
    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        let request = try await inputValue.request(.output)
        let sign = try await FindStringInDomSearch(FileIDMatch.sign, configures: configures, key: key).execute(for: request)
        return inputValue
            .assign(sign, forKey: .sign)
            .assign(sign, forKey: .output)
            .assign(request, forKey: .lastRequest)
    }
    
    public func sessionKey(_ value: SessionKey) -> Self {
        .init(configures, key: value)
    }
}
