//
//  DownURLGenerator.swift
//  WebShell
//
//  Created by john on 2023/5/4.
//  Copyright © 2023 ascp. All rights reserved.
//

import Foundation
#if COMBINE_LINUX && canImport(CombineX)
import CombineX
#else
import Combine
#endif

#if canImport(Durex)
import Durex
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// 从下载链接中抓取fileid，并生成下载link页面请求，
/// 如：`/file-12345.html` -> 取出`12345`，
/// 然后生成`action=load_down_addr1&file_id=12345的body`请求`ajax.php`
public struct FileListURLRequestGenerator: Condom {
    public typealias Input = String
    public typealias Output = URLRequest
    
    let finder: FileIDFinder
    let action: String
    
    public init(_ finder: FileIDFinder, action: String) {
        self.finder = finder
        self.action = action
    }
    
    public init(_ finder: FileIDFinder) {
        self.finder = finder
        self.action = ""
    }
    
    public func action(_ value: String) -> Self {
        FileListURLRequestGenerator(finder, action: value)
    }
    
    public func finder(_ value: FileIDFinder) -> Self {
        FileListURLRequestGenerator(value, action: action)
    }
    
    public func publisher(for inputValue: String) -> AnyPublisher<Output, Error> {
        Future {
            try await AsyncFileListURLRequestGenerator(finder, action: action)
                .execute(for: inputValue)
                .build()
        }
        .eraseToAnyPublisher()
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
}

public struct AsyncFileListURLRequestGenerator: Dirtyware {
    public typealias Input = String
    public typealias Output = URLRequestBuilder
    
    let finder: FileIDFinder
    let action: String
    
    public init(_ finder: FileIDFinder, action: String) {
        self.finder = finder
        self.action = action
    }
    
    public init(_ finder: FileIDFinder) {
        self.finder = finder
        self.action = ""
    }
    
    public func action(_ value: String) -> Self {
        .init(finder, action: value)
    }
    
    public func finder(_ value: FileIDFinder) -> Self {
        .init(value, action: action)
    }
    
    public func execute(for inputValue: String) async throws -> URLRequestBuilder {
        try request(inputValue)
    }
    
    private func request(_ string: String) throws -> URLRequestBuilder {
        guard let url = URL(string: string),
                let component = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw ShellError.badURL(string)
        }
        
        guard let host = component.host, let scheme = component.scheme else {
            throw ShellError.badURL(string)
        }
        
        let fileid = try finder.extract(string)
        return ReferDownPageRequest(fileid: fileid, refer: string, scheme: scheme, host: host, action: action).make()
    }
}
   

/// 下载网页内容并转成字符串，在网页内匹配id，然后在生成文件下载地址请求。
/// 如：`/abcde.html` -> 取出`down_process(1002)` -> `10002`就是Fileid，
/// 然后生成`action=load_down_addr1&file_id=1002`的body, 请求`ajax.php`
public struct FileListURLRequestInPageGenerator: SessionableCondom {
    public typealias Input = String
    public typealias Output = URLRequest
    
    public var key: AnyHashable
    public let finder: FileIDFinder
    public let action: String
    
    public init(_ finder: FileIDFinder, action: String, key: AnyHashable = "default") {
        self.finder = finder
        self.key = key
        self.action = action
    }
    
    public func publisher(for inputValue: String) -> AnyPublisher<Output, Error> {
        Future {
            try await AsyncFileListURLRequestInPageGenerator(finder, action: action, configures: .shared, key: key).execute(for: inputValue).build()
        }
        .eraseToAnyPublisher()
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        Self(finder, action: action, key: value)
    }
}

public struct AsyncFileListURLRequestInPageGenerator: SessionableDirtyware {
    public typealias Input = String
    public typealias Output = URLRequestBuilder
    
    public var key: AnyHashable
    public let finder: FileIDFinder
    public let action: String
    public let configures: Durex.AsyncURLSessionConfiguration
    
    public init(_ finder: FileIDFinder, action: String, configures: Durex.AsyncURLSessionConfiguration, key: AnyHashable = "default") {
        self.finder = finder
        self.key = key
        self.action = action
        self.configures = configures
    }
    
    public func execute(for inputValue: String) async throws -> URLRequestBuilder {
        let request = try request(inputValue)
        let fileid = try await AsyncFileIDStringInDomSearch(finder, configures: configures).execute(for: request)
        let next = try referRequest(inputValue, fileid: fileid)
        return next
    }
    
    func request(_ string: String) throws -> URLRequestBuilder {
        guard let url = URL(string: string),
                let component = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw ShellError.badURL(string)
        }
        
        guard let host = component.host, let scheme = component.scheme else {
            throw ShellError.badURL(string)
        }
        
        return DashDownPageRequest(refer: string, scheme: scheme, host: host).make()
    }
    
    func referRequest(_ string: String, fileid: String) throws -> URLRequestBuilder {
        guard let url = URL(string: string),
                let component = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw ShellError.badURL(string)
        }
        
        guard let host = component.host, let scheme = component.scheme else {
            throw ShellError.badURL(string)
        }
        
        return ReferDownPageRequest(fileid: fileid, refer: string, scheme: scheme, host: host, action: action).make()
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        Self(finder, action: action, configures: configures, key: value)
    }
}

public struct HTTPString: SessionableCondom {
    public typealias Input = String
    public typealias Output = String
    
    public var key: AnyHashable
    
    public init(_ key: AnyHashable = "default") {
        self.key = key
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        Self(value)
    }
    
    public func publisher(for inputValue: String) -> AnyPublisher<String, Error> {
        Future {
            try await AsyncHTTPString(.shared, key: key).execute(for: inputValue)
        }
        .eraseToAnyPublisher()
    }
    
    public func empty() -> AnyPublisher<String, Error> {
        Empty().eraseToAnyPublisher()
    }
}

public struct AsyncHTTPString: SessionableDirtyware {
    
    public typealias Input = String
    public typealias Output = String
    
    public var key: AnyHashable
    public let configures: Durex.AsyncURLSessionConfiguration
    
    public init(_ configures: Durex.AsyncURLSessionConfiguration, key: AnyHashable = "default") {
        self.key = key
        self.configures = configures
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        .init(configures, key: value)
    }
    
    public func execute(for inputValue: String) async throws -> String {
        if inputValue.hasPrefix("http") {
            return inputValue
        }
        return "http://\(inputValue)"
    }
}
