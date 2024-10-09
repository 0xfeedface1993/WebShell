//
//  File.swift
//  
//
//  Created by john on 2023/9/12.
//

import Foundation
import Durex

/// 验证码下载
public struct CodeImageRequest: SessionableDirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public let key: SessionKey
    public var configures: AsyncURLSessionConfiguration
    
    public init(_ configures: AsyncURLSessionConfiguration, key: SessionKey = .host("default")) {
        self.key = key
        self.configures = configures
    }
    
    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        try await CodeImageCustomPathRequest("includes/imgcode.inc.php?verycode_type=2", configures: configures, key: key)
            .execute(for: inputValue)
    }
    
    public func sessionKey(_ value: SessionKey) -> Self {
        .init(configures, key: value)
    }
}

public struct CodeImageCustomPathRequest: SessionableDirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public let key: SessionKey
    public var configures: AsyncURLSessionConfiguration
    public let path: String
    
    public init(_ path: String, configures: AsyncURLSessionConfiguration, key: SessionKey = .host("default")) {
        self.key = key
        self.configures = configures
        self.path = path
    }
    
    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        let lastRequest = try await inputValue.request(.lastRequest)
        guard let url = lastRequest.url else {
            throw ShellError.badURL(lastRequest.url ?? "")
        }
        let next = try Request(url: url, path: path).make()
        return inputValue.assign(next, forKey: .output)
    }
    
    public func sessionKey(_ value: SessionKey) -> Self {
        .init(path, configures: configures, key: value)
    }
    
    struct Request {
        let url: String
        let path: String
        
        func make() throws -> URLRequestBuilder {
            let (host, scheme) = try url.baseComponents()
            let prefix = "\(scheme)://\(host)"
            let next = "\(prefix)/\(path)"
            return URLRequestBuilder(next)
                .method(.get)
                .add(value: "image/webp,image/avif,video/*;q=0.8,image/png,image/svg+xml,image/*;q=0.8,*/*;q=0.5", forKey: "accept")
                .add(value: userAgent, forKey: "user-agent")
                .add(value: url, forKey: "referer")
                .add(value: "en-US,en;q=0.9", forKey: "accept-language")
                .add(value: "keep-alive", forKey: "Connection")
        }
    }
}
