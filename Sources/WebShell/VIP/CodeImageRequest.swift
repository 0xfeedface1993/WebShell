//
//  File.swift
//  
//
//  Created by john on 2023/9/12.
//

import Foundation
import Durex

public enum URLPath: Sendable {
    case incImgCode(veryCodeType: Int)
    case imageCodePHP
    case custom(String)
    
    var description: String {
        switch self {
        case .incImgCode(let veryCodeType):
            return "includes/imgcode.inc.php?verycode_type=\(veryCodeType)"
        case .imageCodePHP:
            return "imagecode.php"
        case .custom(let string):
            return string
        }
    }
}

/// 验证码下载
public struct CodeImageRequest: SessionableDirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public let key: SessionKey
    public var configures: AsyncURLSessionConfiguration
    public let path: URLPath
    
    public init(_ configures: AsyncURLSessionConfiguration, path: URLPath = .incImgCode(veryCodeType: 2), key: SessionKey = .host("default")) {
        self.key = key
        self.configures = configures
        self.path = path
    }
    
    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        try await CodeImageCustomPathRequest(path.description, configures: configures, key: key)
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
                .add(.allImageAccept)
                .add(.customUserAgent)
                .add(value: url, forKey: .referer)
                .add(.enUSAcceptLanguage)
                .add(.keepAliveConnection)
        }
    }
}
