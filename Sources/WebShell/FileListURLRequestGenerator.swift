//
//  DownURLGenerator.swift
//  WebShell
//
//  Created by john on 2023/5/4.
//  Copyright © 2023 ascp. All rights reserved.
//

import Foundation
import Combine
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
