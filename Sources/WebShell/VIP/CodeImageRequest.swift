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
    
    public var key: AnyHashable
    public var configures: AsyncURLSessionConfiguration
    
    public init(_ configures: AsyncURLSessionConfiguration, key: AnyHashable = "default") {
        self.key = key
        self.configures = configures
    }
    
    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        let lastRequest = try inputValue.request(.lastRequest)
        guard let url = lastRequest.url else {
            throw ShellError.badURL(lastRequest.url ?? "")
        }
        let next = try Request(url: url).make()
        return inputValue.assign(next, forKey: .lastOutput)
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        .init(configures, key: value)
    }
    
    struct Request {
        let url: String
        
        func make() throws -> URLRequestBuilder {
            let (host, scheme) = try url.baseComponents()
            let prefix = "\(scheme)://\(host)"
            let next = "\(prefix)/includes/imgcode.inc.php?verycode_type=2"
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
