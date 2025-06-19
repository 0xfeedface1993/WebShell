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

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// 从下载链接中抓取fileid，并生成下载link页面请求，
/// 如：`/file-12345.html` -> 取出`12345`，
/// 然后生成`action=load_down_addr1&file_id=12345的body`请求`ajax.php`
public struct DownPage: Dirtyware {
    public typealias Input = String
    public typealias Output = URLRequestBuilder
    
    let finder: FileIDFinder
    
    public init(_ finder: FileIDFinder) {
        self.finder = finder
    }
    
    public func execute(for inputValue: String) async throws -> URLRequestBuilder {
        try await FileListURLRequestGenerator(finder, action: "load_down_addr1").execute(for: inputValue)
    }
}

public struct DashDownPageRequest {
    let refer: String
    let scheme: String
    let host: String
    
    func make() -> URLRequestBuilder {
        let http = "\(scheme)://\(host)"
        let url = "\(http)/down/\(refer.components(separatedBy: "/").last ?? "")"
        return URLRequestBuilder(url)
            .add(value: "1", forKey: "Upgrade-Insecure-Requests")
            .add(value: fullAccept, forKey: "Accept")
            .add(value: "zh-CN,zh-Hans;q=0.9", forKey: "Accept-Language")
            .add(value: userAgent, forKey: "User-Agent")
            .add(value: refer, forKey: "Referer")
    }
}

public struct ReferDownPageRequest {
    let fileid: String
    let refer: String
    let scheme: String
    let host: String
    let action: String
    
    func make() -> URLRequestBuilder {
        let http = "\(scheme)://\(host)"
        let url = "\(http)/ajax.php"
        return URLRequestBuilder(url)
            .method(.post)
            .add(value: "text/plain, */*; q=0.01", forKey: "Accept")
            .add(value: "XMLHttpRequest", forKey: "X-Requested-With")
            .add(value: "zh-CN,zh-Hans;q=0.9", forKey: "Accept-Language")
            .add(value: LinkRequestHeader.urlencodedContentType.value, forKey: LinkRequestHeader.urlencodedContentType.key.rawValue)
            .add(value: http, forKey: LinkRequestHeader.Key.origin.rawValue)
            .add(value: userAgent, forKey: "User-Agent")
            .add(value: refer, forKey: "Referer")
            .body("action=\(action)&file_id=\(fileid)".data(using: .utf8) ?? Data())
    }
}

public struct FormDownloadLinksRequest {
    enum Param: Sendable {
        case checkCode(fileID: String, action: String, code: String)
    }
    
    let param: Param
    let refer: String
    let scheme: String
    let host: String
    
    func make() -> URLRequestBuilder {
        let http = "\(scheme)://\(host)"
        let url = "\(http)/ajax.php"
        var builder = URLRequestBuilder(url)
            .method(.post)
            .add(value: LinkRequestHeader.allCapAccept.value, forKey: LinkRequestHeader.allCapAccept.key.rawValue)
            .add(value: "XMLHttpRequest", forKey: "X-Requested-With")
            .add(value: "zh-CN,zh-Hans;q=0.9", forKey: LinkRequestHeader.enUSAcceptLanguage.key.rawValue)
            .add(value: LinkRequestHeader.urlencodedContentType.value, forKey: LinkRequestHeader.urlencodedContentType.key.rawValue)
            .add(value: http, forKey: LinkRequestHeader.Key.origin.rawValue)
            .add(value: userAgent, forKey: "User-Agent")
            .add(value: refer, forKey: "Referer")
            .add(value: "u=3, i", forKey: LinkRequestHeader.priority.key.rawValue)
        switch param {
        case .checkCode(let fileID, let action, let code):
            builder = builder.body(
                "action=\(action)&file_id=\(fileID)&code=\(code)".data(using: .utf8) ?? Data()
            )
        }
        return builder
    }
}

public struct GeneralDownPage {
    let scheme: String
    let fileid: String
    let host: String
    let refer: String
    
    func make() -> URLRequestBuilder {
        let http = "\(scheme)://\(host)"
        let url = "\(http)/ajax.php"
        return URLRequestBuilder(url)
            .method(.post)
            .add(value: "text/plain, */*; q=0.01", forKey: "accept")
            .add(value: "XMLHttpRequest", forKey: "x-requested-with")
            .add(value: "zh-CN,zh-Hans;q=0.9", forKey: "accept-language")
            .add(value: "application/x-www-form-urlencoded; charset=UTF-8", forKey: "content-type")
            .add(value: http, forKey: "Origin")
            .add(value: userAgent, forKey: "user-agent")
            .add(value: refer, forKey: "referer")
            .body("action=load_down_addr1&file_id=\(fileid)".data(using: .utf8) ?? Data())
    }
}

public struct ReferSignDownPageRequest {
    let fileid: String
    let refer: String
    let scheme: String
    let host: String
    let action: String
    let sign: String
    
    func make() -> URLRequestBuilder {
        let http = "\(scheme)://\(host)"
        let url = "\(http)/ajax.php"
        return URLRequestBuilder(url)
            .method(.post)
            .add(value: "text/plain, */*; q=0.01", forKey: "Accept")
            .add(value: "XMLHttpRequest", forKey: "X-Requested-With")
            .add(value: "zh-CN,zh-Hans;q=0.9", forKey: "Accept-Language")
            .add(value: "application/x-www-form-urlencoded; charset=UTF-8", forKey: "Content-Type")
            .add(value: http, forKey: "Origin")
            .add(value: userAgent, forKey: "User-Agent")
            .add(value: refer, forKey: "Referer")
            .body("action=\(action)&sign=\(sign)&file_id=\(fileid)".data(using: .utf8) ?? Data())
    }
}

public struct DownPageCustomHeaderRequest {
    let scheme: String
    let host: String
    let fileid: String
    
    func make(_ builder: (URLRequestBuilder) -> URLRequestBuilder) -> URLRequestBuilder {
        let http = "\(scheme)://\(host)"
        let url = "\(http)/down-\(fileid).html"
        return builder(URLRequestBuilder(url))
    }
}

public struct JustRequest {
    let url: String
    
    func make() throws -> URLRequestBuilder {
        URLRequestBuilder(url)
            .add(value: fullAccept, forKey: "Accept")
            .add(value: "1", forKey: "Upgrade-Insecure-Requests")
            .add(value: "zh-CN,zh-Hans;q=0.9", forKey: "Accept-Language")
            .add(value: "application/x-www-form-urlencoded; charset=UTF-8", forKey: "Content-Type")
            .add(value: userAgent, forKey: "User-Agent")
    }
}
