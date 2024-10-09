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

/// Read url string from key store, and request it, save file to `htmlFile` key, and save url string to `output` key
public struct URLPageReader: SessionableDirtyware {
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
        let string = try await inputValue.string(stringKey)
        let request = try JustRequest(url: string).make()
        let context = try await AsyncSession(configures).context(key)
        let (data, response) = try await context.download(with: request)
        let next = inputValue
            .assign(request, forKey: .lastRequest)
            .assign(data, forKey: .htmlFile)
        if let redirectURL = validRedirectResponse(response, request: request.url) {
            return next.assign(redirectURL.absoluteString, forKey: .output)
        }
        return next.assign(string, forKey: .output)
    }
    
    private func validRedirectResponse(_ value: URLResponse, request: String?) -> URL? {
        guard let url = value.url, let origin = request, let originURL = URL(string: origin), value.url != originURL else {
            return nil
        }
        return url
    }
    
    public func sessionKey(_ value: SessionKey) -> Self {
        .init(stringKey, configures: configures, key: value)
    }
}


