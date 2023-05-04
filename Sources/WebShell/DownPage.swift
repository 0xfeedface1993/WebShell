//
//  DownPage.swift
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

/// 从下载链接中抓取fileid，并生成下载link页面请求，
/// 如：`/file-12345.html` -> 取出`12345`，
/// 然后生成`action=load_down_addr1&file_id=12345的body`请求`ajax.php`
public struct DownPage: Condom {
    public typealias Input = String
    public typealias Output = URLRequest
    
    let finder: FileIDFinder
    
    public init(_ finder: FileIDFinder) {
        self.finder = finder
    }
    
    public func publisher(for inputValue: String) -> AnyPublisher<Output, Error> {
        FileListURLRequestGenerator(finder, action: "load_down_addr1")
            .publisher(for: inputValue)
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
}

public struct ActionDownPage: SessionableCondom {
    public typealias Input = String
    public typealias Output = URLRequest
    
    public var key: AnyHashable
    
    public init(_ key: AnyHashable = "default") {
        self.key = key
    }
    
    public func publisher(for inputValue: String) -> AnyPublisher<Output, Error> {
        do {
            let data = try request(inputValue)
            return StringParserDataTask(request: data, encoding: .utf8, sessionKey: key)
                .publisher()
                .tryMap { try FileIDMatch.downProcess4.extract($0) }
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
        
        return try ReferDownPageRequest(fileid: fileid, refer: string, scheme: scheme, host: host, action: "load_down_addr5").make()
    }
    
    public func sessionKey(_ value: AnyHashable) -> ActionDownPage {
        ActionDownPage(value)
    }
}

public struct DashDownPageRequest {
    let refer: String
    let scheme: String
    let host: String
    
    func make() throws -> URLRequest {
        let http = "\(scheme)://\(host)"
        let url = "\(http)/down/\(refer.components(separatedBy: "/").last ?? "")"
        return try URLRequestBuilder(url)
            .add(value: "1", forKey: "Upgrade-Insecure-Requests")
            .add(value: fullAccept, forKey: "Accept")
            .add(value: "zh-CN,zh-Hans;q=0.9", forKey: "Accept-Language")
            .add(value: userAgent, forKey: "User-Agent")
            .add(value: refer, forKey: "Referer")
            .build()
    }
}

public struct ReferDownPageRequest {
    let fileid: String
    let refer: String
    let scheme: String
    let host: String
    let action: String
    
    func make() throws -> URLRequest {
        let http = "\(scheme)://\(host)"
        let url = "\(http)/ajax.php"
        return try URLRequestBuilder(url)
            .method(.post)
            .add(value: "text/plain, */*; q=0.01", forKey: "Accept")
            .add(value: "XMLHttpRequest", forKey: "X-Requested-With")
            .add(value: "zh-CN,zh-Hans;q=0.9", forKey: "Accept-Language")
            .add(value: "application/x-www-form-urlencoded; charset=UTF-8", forKey: "Content-Type")
            .add(value: http, forKey: "Origin")
            .add(value: userAgent, forKey: "User-Agent")
            .add(value: refer, forKey: "Referer")
            .body("action=\(action)&file_id=\(fileid)".data(using: .utf8) ?? Data())
            .build()
    }
}

public struct GeneralDownPage {
    let scheme: String
    let fileid: String
    let host: String
    let refer: String
    
    func make() throws -> URLRequest {
        let http = "\(scheme)://\(host)"
        let url = "\(http)/ajax.php"
        return try URLRequestBuilder(url)
            .method(.post)
            .add(value: "text/plain, */*; q=0.01", forKey: "accept")
            .add(value: "XMLHttpRequest", forKey: "x-requested-with")
            .add(value: "zh-CN,zh-Hans;q=0.9", forKey: "accept-language")
            .add(value: "application/x-www-form-urlencoded; charset=UTF-8", forKey: "content-type")
            .add(value: http, forKey: "Origin")
            .add(value: userAgent, forKey: "user-agent")
            .add(value: refer, forKey: "referer")
            .body("action=load_down_addr1&file_id=\(fileid)".data(using: .utf8) ?? Data())
            .build()
    }
}

public struct JustRequest {
    let url: String
    
    func make() throws -> URLRequest {
        try URLRequestBuilder(url)
            .add(value: fullAccept, forKey: "Accept")
            .add(value: "1", forKey: "Upgrade-Insecure-Requests")
            .add(value: "zh-CN,zh-Hans;q=0.9", forKey: "Accept-Language")
            .add(value: "application/x-www-form-urlencoded; charset=UTF-8", forKey: "Content-Type")
            .add(value: userAgent, forKey: "User-Agent")
            .build()
    }
}

public struct RedirectEnablePage: SessionableCondom {
    public typealias Input = String
    public typealias Output = String
    
    public var key: AnyHashable
    
    public init(_ key: AnyHashable = "default") {
        self.key = key
    }
    
    public func publisher(for inputValue: String) -> AnyPublisher<Output, Error> {
        do {
            let request = try JustRequest(url: inputValue).make()
            return SessionPool
                .context(key)
                .flatMap({ context in
                    context.download(with: request)
                        .map(\.1)
                        .tryMap { try validRedirectResponse($0, request: request) }
                        .map({ _ in inputValue })
                        .tryCatch(catchRedirectError(_:))
                })
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    private func validRedirectResponse(_ value: URLResponse, request: URLRequest) throws -> URLResponse {
        guard let url = value.url, value.url != request.url else {
            return value
        }
        throw ShellError.redirect(url)
    }
    
    private func catchRedirectError(_ error: Error) throws -> AnyPublisher<Output, Error> {
        guard case ShellError.redirect(let url) = error else {
            throw error
        }
        return AnyValue(url.absoluteString).eraseToAnyPublisher()
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
    
    public func sessionKey(_ value: AnyHashable) -> RedirectEnablePage {
        RedirectEnablePage(value)
    }
}
