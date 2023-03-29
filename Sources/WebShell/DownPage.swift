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
    
    public init() { }
    
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
    
    func request(_ string: String) throws -> URLRequest {
        guard let url = URL(string: string),
                let component = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw ShellError.badURL(string)
        }
        
        guard let host = component.host, let scheme = component.scheme else {
            throw ShellError.badURL(string)
        }
        
        let fileid = try FileIDMatch(url: string).extract()
        return try DownPageRequest(fileid: fileid, scheme: scheme, host: host).make()
    }
}

public struct DownPageRequest {
    let fileid: String
    let scheme: String
    let host: String
    
    func make() throws -> URLRequest {
        let http = "\(scheme)://\(host)"
        let refer = "\(http)/down-\(fileid).html"
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
            .body("action=load_down_addr1&file_id=\(fileid)".data(using: .utf8) ?? Data())
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
