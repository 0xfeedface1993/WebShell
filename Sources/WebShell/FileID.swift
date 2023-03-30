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

/// 从链接中提取fileid，`http://xxxx/file-123456.html`提取fileid`123456`
public struct FileIDMatch {
    let url: String
    let pattern = "\\-(\\w+)\\.\\w+"
    
    func extract() throws -> String {
        if #available(iOS 16.0, macOS 13.0, *) {
            let regx = try Regex(pattern)
            guard let match = url.firstMatch(of: regx),
                    let fileid = match.output[1].substring else {
                throw ShellError.badURL(url)
            }
            return String(fileid)
        } else {
            // Fallback on earlier versions
            let regx = try NSRegularExpression(pattern: pattern)
            let nsString = url as NSString
            guard let result = regx.firstMatch(in: url, range: .init(location: 0, length: nsString.length)) else {
                throw ShellError.badURL(url)
            }
            return regx.replacementString(for: result, in: url, offset: 0, template: "$1")
        }
    }
}

/// 从html代码中获取fileid，如：`load_down_addr1('123455')` -> 123455
struct FileIDInFunctionParameter {
    let html: String
    let pattern = "load_down_addr1\\('([\\w\\d]+)'\\)"
    
    func extract() throws -> String {
        if #available(iOS 16.0, macOS 13.0, *) {
            let regx = try Regex(pattern)
            guard let fileid = html.firstMatch(of: regx)?.output[1].substring else {
                throw ShellError.noFileID
            }
            return String(fileid)
        } else {
            // Fallback on earlier versions
            let regx = try NSRegularExpression(pattern: pattern)
            let nsString = html as NSString
            let range = NSRange(location: 0, length: nsString.length)
            guard let fileid = regx.firstMatch(in: html, range: range) else {
                throw ShellError.noFileID
            }
            return regx.replacementString(for: fileid, in: html, offset: 0, template: "$1")
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
public struct FileIDStringInDomSearch: Condom {
    public typealias Input = URLRequest
    public typealias Output = String
    
    public init() { }
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        StringParserDataTask(request: inputValue, encoding: .utf8)
            .publisher()
            .tryMap { html in
                try FileIDInFunctionParameter(html: html).extract()
            }
            .eraseToAnyPublisher()
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
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
public struct FileIDStringInDomSearchGroup: Condom {
    public typealias Input = URLRequest
    public typealias Output = URLRequest
    
    public init() { }
    
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
        
        let searchid = FileIDStringInDomSearch()
        let page = GeneralDownPageByID(scheme: scheme, host: host, refer: url.absoluteString)
        
        return searchid.join(page)
    }
}
