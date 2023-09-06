//
//  File.swift
//  
//
//  Created by john on 2023/9/6.
//

import Foundation

#if canImport(Durex)
import Durex
#endif

#if COMBINE_LINUX && canImport(CombineX)
import CombineX
#else
import Combine
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// 生成下载链接获取请求，给path添加`/d`前缀，如：`https://xxx/6emc775g2p/apple.rar.html` -> `https://xxx/d/6emc775g2p/apple.rar.html`
public struct AppendDownPath: Condom {
    public typealias Input = String
    public typealias Output = URLRequest
    
    public init() { }
    
    public func publisher(for inputValue: String) -> AnyPublisher<Output, Error> {
        Future {
            try await AsyncAppendDownPath().execute(for: inputValue).build()
        }
        .eraseToAnyPublisher()
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
}

public struct AsyncAppendDownPath: Dirtyware {
    public typealias Input = String
    public typealias Output = URLRequestBuilder
    
    public init() {
        
    }
    
    public func execute(for inputValue: String) async throws -> URLRequestBuilder {
        try remake(inputValue)
    }
    
    func remake(_ string: String) throws -> URLRequestBuilder {
        guard let url = URL(string: string),
                var component = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw ShellError.badURL(string)
        }
        
        component.path = "/d\(component.path)"
        
        guard let next = component.url?.absoluteString else {
            throw ShellError.badURL(component.path)
        }
        
        return URLRequestBuilder(next)
            .add(value: fullAccept, forKey: "Accept")
            .add(value: userAgent, forKey: "user-agent")
            .add(value: string, forKey: "referer")
            .add(value: "zh-CN,zh-Hans;q=0.9", forKey: "Accept-Language")
    }
}
