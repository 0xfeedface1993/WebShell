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
        do {
            return AnyValue(try request(inputValue)).eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
    
    private func request(_ string: String) throws -> URLRequest {
        guard let url = URL(string: string),
                let component = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw ShellError.badURL(string)
        }
        
        guard let host = component.host, let scheme = component.scheme else {
            throw ShellError.badURL(string)
        }
        
        let fileid = try finder.extract(string)
        return try ReferDownPageRequest(fileid: fileid, refer: string, scheme: scheme, host: host, action: action).make()
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
        do {
            let data = try request(inputValue)
            return StringParserDataTask(request: data, encoding: .utf8, sessionKey: key)
                .publisher()
                .tryMap { try finder.extract($0) }
                .tryMap { try referRequest(inputValue, fileid: $0) }
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
    
    func request(_ string: String) throws -> URLRequest {
        guard let url = URL(string: string),
                let component = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw ShellError.badURL(string)
        }
        
        guard let host = component.host, let scheme = component.scheme else {
            throw ShellError.badURL(string)
        }
        
        return try DashDownPageRequest(refer: string, scheme: scheme, host: host).make()
    }
    
    func referRequest(_ string: String, fileid: String) throws -> URLRequest {
        guard let url = URL(string: string),
                let component = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw ShellError.badURL(string)
        }
        
        guard let host = component.host, let scheme = component.scheme else {
            throw ShellError.badURL(string)
        }
        
        return try ReferDownPageRequest(fileid: fileid, refer: string, scheme: scheme, host: host, action: action).make()
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        Self(finder, action: action, key: value)
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
        if inputValue.hasPrefix("http") {
            return AnyValue(inputValue).eraseToAnyPublisher()
        }
        return AnyValue("http://\(inputValue)").eraseToAnyPublisher()
    }
    
    public func empty() -> AnyPublisher<String, Error> {
        Empty().eraseToAnyPublisher()
    }
}
