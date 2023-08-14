//
//  File.swift
//  
//
//  Created by john on 2023/8/7.
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

/// 下载网页内容并转成字符串，在网页内匹配sign值和fileid，然后在生成文件下载地址请求。
/// 如：`/file-1234.html` -> 取出`1234`就是Fileid，
/// 然后访问`/down-1234.htm` -> 取出`sign=abcdefg` -> `abcdefg`就是sign值，
/// 最后生成`action=load_down_addr10&sign=abcdefg&file_id=1234`的body, 请求`ajax.php`
public struct TowerFileListRequestGenerator: SessionableCondom {
    public typealias Input = String
    public typealias Output = URLRequest
    
    public var key: AnyHashable
    public let fileid: String
    public let action: String
    public let url: String
    
    public init(_ fileid: String, action: String, url: String, key: AnyHashable = "default") {
        self.fileid = fileid
        self.key = key
        self.action = action
        self.url = url
    }
    
    public func publisher(for inputValue: String) -> AnyPublisher<Output, Error> {
        do {
            return AnyValue(try request(url, fileid: fileid)).eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
    
    func request(_ string: String, fileid: String) throws -> URLRequest {
        let (host, scheme) = try string.baseComponents()
        return try ReferDownPageRequest(fileid: fileid, refer: "\(scheme)://\(host)", scheme: scheme, host: host, action: action).make()
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        Self(fileid, action: action, url: url, key: value)
    }
}

public struct TowerFileListRequestGeneratorGroup: SessionableCondom {
    public typealias Input = URLRequest
    public typealias Output = URLRequest
    
    public let fileid: String
    public let action: String
    public var key: AnyHashable
    
    public init(_ fileid: String, action: String, key: AnyHashable = "default") {
        self.fileid = fileid
        self.action = action
        self.key = key
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        .init(fileid, action: action, key: value)
    }
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        TowerCookieUpdate(fileid: fileid, key: key)
            .join(TowerFileListRequestGenerator(fileid, action: action, url: inputValue.url?.absoluteString ?? "", key: key))
            .publisher(for: inputValue)
            .eraseToAnyPublisher()
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
}

public struct TowerGroup: SessionableCondom {
    public typealias Input = String
    public typealias Output = URLRequest
    
    public let action: String
    public var key: AnyHashable
    
    public init(_ action: String, key: AnyHashable = "default") {
        self.action = action
        self.key = key
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        .init(action, key: value)
    }
    
    private func fileid(_ string: String) throws -> String {
        try FileIDMatch.default.extract(string)
    }
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        do {
            let fileid = try fileid(inputValue)
            return TowerJSPage(key)
                .join(TowerFileListRequestGeneratorGroup(fileid, action: action, key: key))
                .publisher(for: inputValue)
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
}
