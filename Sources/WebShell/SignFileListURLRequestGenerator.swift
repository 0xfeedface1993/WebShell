//
//  SignFileListURLRequestGenerator.swift
//  WebShellExsample
//
//  Created by john on 2023/6/28.
//  Copyright © 2023 ascp. All rights reserved.
//

import Foundation

#if canImport(Durex)
import Durex
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// 下载网页内容并转成字符串，在网页内匹配sign值和fileid，然后在生成文件下载地址请求。
/// 如：`/file-1234.html` -> 取出`1234`就是Fileid，
/// 然后访问`/down-1234.htm` -> 取出`sign=abcdefg` -> `abcdefg`就是sign值，
/// 最后生成`action=load_down_addr10&sign=abcdefg&file_id=1234`的body, 请求`ajax.php`
public struct SignFileListURLRequestGenerator: SessionableDirtyware {
    public typealias Input = String
    public typealias Output = URLRequestBuilder
    
    public let key: SessionKey
    /// 文件id查找器，这里应该是URL上匹配
    public let finder: FileIDFinder
    public let action: String
    public let configures: AsyncURLSessionConfiguration
    
    public init(_ finder: FileIDFinder, action: String, configures: AsyncURLSessionConfiguration, key: SessionKey = .host("default")) {
        self.finder = finder
        self.key = key
        self.action = action
        self.configures = configures
    }
    
    public func execute(for inputValue: String) async throws -> URLRequestBuilder {
        let fileid = try finder.extract(inputValue)
        let request = try await SignFileDownPage(fileid: fileid).execute(for: inputValue)
        let string = try await StringParserDataTask(request: request, encoding: .utf8, sessionKey: key, configures: configures).asyncValue()
        let sign = try FileIDMatch.sign.extract(string)
        shellLogger.info("[\(type(of: self))] match sign \(sign) for origin link \(inputValue).")
        return try makeRequest(inputValue, fileid: fileid, sign: sign)
    }
    
    func makeRequest(_ string: String, fileid: String, sign: String) throws -> URLRequestBuilder {
        guard let url = URL(string: string),
                let component = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw ShellError.badURL(string)
        }
        
        guard let host = component.host, let scheme = component.scheme else {
            throw ShellError.badURL(string)
        }
        
        return ReferSignDownPageRequest(fileid: fileid, refer: string, scheme: scheme, host: host, action: action, sign: sign).make()
    }
    
    public func sessionKey(_ value: SessionKey) -> Self {
        Self(finder, action: action, configures: configures, key: value)
    }
}

