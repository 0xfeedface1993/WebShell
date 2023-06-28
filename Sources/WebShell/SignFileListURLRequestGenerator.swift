//
//  SignFileListURLRequestGenerator.swift
//  WebShellExsample
//
//  Created by john on 2023/6/28.
//  Copyright © 2023 ascp. All rights reserved.
//

import Foundation
import Combine
#if canImport(Durex)
import Durex
#endif

/// 下载网页内容并转成字符串，在网页内匹配sign值和fileid，然后在生成文件下载地址请求。
/// 如：`/file-1234.html` -> 取出`1234`就是Fileid，
/// 然后访问`/down-1234.htm` -> 取出`sign=abcdefg` -> `abcdefg`就是sign值，
/// 最后生成`action=load_down_addr10&sign=abcdefg&file_id=1234`的body, 请求`ajax.php`
public struct SignFileListURLRequestGenerator: SessionableCondom {
    public typealias Input = String
    public typealias Output = URLRequest
    
    public var key: AnyHashable
    /// 文件id查找器，这里应该是URL上匹配
    public let finder: FileIDFinder
    public let action: String
    
    public init(_ finder: FileIDFinder, action: String, key: AnyHashable = "default") {
        self.finder = finder
        self.key = key
        self.action = action
    }
    
    public func publisher(for inputValue: String) -> AnyPublisher<Output, Error> {
        do {
            // 读取fileid
            let fileid = try finder.extract(inputValue)
            // 转换成down-fileid.html页面
            return RawDownPage(fileid: fileid)
                .publisher(for: inputValue)
                .flatMap {
                    // 下载down-fileid.html页面
                    StringParserDataTask(request: $0, encoding: .utf8, sessionKey: key)
                        .publisher()
                }
                .tryMap {
                    // 解析sign参数
                    let sign = try SingValueMatch().extract($0)
#if DEBUG
                    print(">>> [\(type(of: self))] match sign \(sign) for origin link \(inputValue).")
#endif
                    // 构建下载列表ajax请求
                    return try request(inputValue, fileid: fileid, sign: sign)
                }
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
    
    func request(_ string: String, fileid: String, sign: String) throws -> URLRequest {
        guard let url = URL(string: string),
                let component = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw ShellError.badURL(string)
        }
        
        guard let host = component.host, let scheme = component.scheme else {
            throw ShellError.badURL(string)
        }
        
        return try ReferSignDownPageRequest(fileid: fileid, refer: string, scheme: scheme, host: host, action: action, sign: sign).make()
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        Self(finder, action: action, key: value)
    }
}

public struct SingValueMatch {
    let pattern = "&sign=(\\w+)&"
    
    public func extract(_ text: String) throws -> String {
        try FileIDMatch(pattern).extract(text)
    }
}

