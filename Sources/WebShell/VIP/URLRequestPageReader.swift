//
//  File.swift
//  
//
//  Created by john on 2023/9/19.
//

import Foundation
import Durex

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Read url request from key store, and request it, save file to `htmlFile` key, and save file url to `output` key
public struct URLRequestPageReader: SessionableDirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public let key: SessionKey
    public var configures: AsyncURLSessionConfiguration
    public var stringKey: KeyStore.Key
    
    public init(_ stringKey: KeyStore.Key, configures: AsyncURLSessionConfiguration, key: SessionKey) {
        self.key = key
        self.configures = configures
        self.stringKey = stringKey
    }
    
    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        let request = try await inputValue.request(stringKey)
        let context = try await AsyncSession(configures).context(key)
        let (data, _) = try await context.download(with: request)
        let next = inputValue
            .assign(request, forKey: .lastRequest)
            .assign(data, forKey: .htmlFile)
        return next.assign(data, forKey: .output)
    }
    
    public func sessionKey(_ value: SessionKey) -> Self {
        .init(stringKey, configures: configures, key: value)
    }
}
