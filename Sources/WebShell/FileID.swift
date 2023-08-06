//
//  FileID.swift
//  WebShellExsample
//
//  Created by john on 2023/3/29.
//  Copyright © 2023 ascp. All rights reserved.
//

import Foundation
#if canImport(Durex)
import Durex
#endif
import Combine

public protocol FileIDFinder {
    init(_ pattern: String)
    
    func extract(_ text: String) throws -> String
}

extension FileIDFinder where Self == FileIDMatch {
    public static var `default`: Self {
        FileIDMatch("\\-(\\w+)\\.\\w+$")
    }
    
    public static var loadDownAddr1: Self {
        FileIDMatch("load_down_addr1\\('([\\w\\d]+)'\\)")
    }
    
    public static var downProcess4: Self {
        FileIDMatch("down_process4\\(\"([\\w\\d]+)\"\\)")
    }
    
    public static var lastPath: Self {
        FileIDMatch("/([\\w\\d]+)$")
    }
}

/// 从链接中提取fileid，`http://xxxx/file-123456.html`提取fileid`123456`
public struct FileIDMatch: FileIDFinder {
    var pattern = "\\-(\\w+)\\.\\w+$"
    
    public init(_ pattern: String) {
        self.pattern = pattern
    }
    
    public func extract(_ text: String) throws -> String {
        if #available(iOS 16.0, macOS 13.0, *) {
            let regx = try Regex(pattern)
            guard let match = text.firstMatch(of: regx),
                    let fileid = match.output[1].substring else {
                throw ShellError.regulaNotMatch(text)
            }
            return String(fileid)
        } else {
            // Fallback on earlier versions
            let regx = try NSRegularExpression(pattern: pattern)
            let nsString = text as NSString
            guard let result = regx.firstMatch(in: text, range: .init(location: 0, length: nsString.length)) else {
                throw ShellError.regulaNotMatch(text)
            }
            return regx.replacementString(for: result, in: text, offset: 0, template: "$1")
        }
    }
}

/// 生成下载链接获取请求，给path添加`/d`前缀，如：`https://xxx/6emc775g2p/apple.rar.html` -> `https://xxx/d/6emc775g2p/apple.rar.html`
public struct AppendDownPath: Condom {
    public typealias Input = String
    public typealias Output = URLRequest
    
    public init() { }
    
    public func publisher(for inputValue: String) -> AnyPublisher<Output, Error> {
        do {
            return AnyValue(try remake(inputValue)).eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
    
    func remake(_ string: String) throws -> URLRequest {
        guard let url = URL(string: string),
                var component = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw ShellError.badURL(string)
        }
        
        component.path = "/d\(component.path)"
        
        guard let next = component.url?.absoluteString else {
            throw ShellError.badURL(component.path)
        }
        
        return try URLRequestBuilder(next)
            .add(value: fullAccept, forKey: "Accept")
            .add(value: userAgent, forKey: "user-agent")
            .add(value: string, forKey: "referer")
            .add(value: "zh-CN,zh-Hans;q=0.9", forKey: "Accept-Language")
            .build()
    }
}

/// 从html代码中获取fileid模块，规则详见``FileIDInFunctionParameter``
public struct FileIDStringInDomSearch: SessionableCondom {
    public typealias Input = URLRequest
    public typealias Output = String
    
    let finder: FileIDFinder
    public var key: AnyHashable
    
    public init(_ finder: FileIDFinder, key: AnyHashable = "default") {
        self.finder = finder
        self.key = key
    }
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        StringParserDataTask(request: inputValue, encoding: .utf8, sessionKey: key)
            .publisher()
            .tryMap(finder.extract(_:))
            .eraseToAnyPublisher()
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
    
    public func sessionKey(_ value: AnyHashable) -> FileIDStringInDomSearch {
        FileIDStringInDomSearch(finder, key: value)
    }
}

/// 基于fileid构造下载链接页面请求
public struct GeneralDownPageByID: Condom {
    public typealias Input = String
    public typealias Output = URLRequest
    
    let scheme: String
    let host: String
    let refer: String
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        do {
            return AnyValue(try GeneralDownPage(scheme: scheme, fileid: inputValue, host: host, refer: refer).make()).eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
}

/// 合并FileIDStringInDomSearch和GeneralDownPageBy两个模块，因后者需要前者的输入链接生成refer，
/// 此模块减少复杂度，后续使用
public struct FileIDStringInDomSearchGroup: SessionableCondom {
    public typealias Input = URLRequest
    public typealias Output = URLRequest
    
    let finder: FileIDFinder
    public var key: AnyHashable
    
    public init(_ finder: FileIDFinder, key: AnyHashable = "default") {
        self.finder = finder
        self.key = key
    }
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        do {
            return try search(inputValue)
                .publisher(for: inputValue)
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
    
    private func search(_ request: URLRequest) throws -> AnyCondom<Input, Output> {
        guard let url = request.url,
                let component = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw ShellError.badURL(request.url?.absoluteString ?? "")
        }
        
        guard let host = component.host, let scheme = component.scheme else {
            throw ShellError.badURL(url.absoluteString)
        }
        
        let searchid = FileIDStringInDomSearch(finder, key: key)
        let page = GeneralDownPageByID(scheme: scheme, host: host, refer: url.absoluteString)
        
        return searchid.join(page)
    }
    
    public func sessionKey(_ value: AnyHashable) -> FileIDStringInDomSearchGroup {
        FileIDStringInDomSearchGroup(finder, key: value)
    }
}
