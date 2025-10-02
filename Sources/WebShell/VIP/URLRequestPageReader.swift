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
        let (data, response) = try await context.download(with: request)
        let next = extractCookies(from: response, to: inputValue)
            .assign(request, forKey: .lastRequest)
            .assign(data, forKey: .htmlFile)
        return next.assign(data, forKey: .output)
    }
    
    public func sessionKey(_ value: SessionKey) -> Self {
        .init(stringKey, configures: configures, key: value)
    }
}

public struct URLRequestPageReaderV2: Dirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public var stringKey: KeyStore.Key
    
    public init(_ stringKey: KeyStore.Key) {
        self.stringKey = stringKey
    }
    
    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        guard let request = try await inputValue.requests(stringKey).first else {
            throw ShellError.emptyRequest
        }
        let key = try await inputValue.sessionKey(.sessionKey)
        let configures = try await inputValue.configures(.configures)
        let context = try await AsyncSession(configures).context(key)
        let (data, _) = try await context.download(with: request)
        shellLogger.info("[\(stringKey)] download at \(data)")
        if let fileURL = try? await inputValue.string(.fileidURL),
            let string = try? String(contentsOf: data, encoding: .utf8) {
            await updateHMCookies(string, fileURL: fileURL, key: key, configures: configures, store: inputValue)
        }
        let next = inputValue
            .assign(request, forKey: .lastRequest)
            .assign(data, forKey: .htmlFile)
        return next.assign(data, forKey: .output)
    }
}

extension HTTPCookie: ContextValue {
    public var valueDescription: String {
        self.description
    }
}

@discardableResult
func extractCookies(from response: URLResponse, to keyStore: KeyStore) -> KeyStore {
    guard let response = response as? HTTPURLResponse,
        let url = response.url,
        let headers = response.allHeaderFields as? [String: String] else {
        return keyStore
    }
    let cookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: url.removeURLPath())
    return keyStore.assign(cookies, forKey: .setCookies)
}
