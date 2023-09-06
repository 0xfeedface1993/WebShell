//
//  File.swift
//  
//
//  Created by john on 2023/8/7.
//

import Foundation
import Durex

#if COMBINE_LINUX && canImport(CombineX)
import CombineX
#else
import Combine
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct TowerCookieUpdate: SessionableCondom {
    typealias Input = URLRequestBuilder
    typealias Output = String
    
    let fileid: String
    let key: AnyHashable
    
    func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        Future {
            try await AsyncTowerCookieUpdate(fileid: fileid, key: key, configures: .shared).execute(for: inputValue)
        }
        .eraseToAnyPublisher()
    }
    
    func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
    
    func sessionKey(_ value: AnyHashable) -> TowerCookieUpdate {
        .init(fileid: fileid, key: value)
    }
}

struct AsyncTowerCookieUpdate: SessionableDirtyware {
    typealias Input = URLRequestBuilder
    typealias Output = String
    
    let fileid: String
    let key: AnyHashable
    let configures: AsyncURLSessionConfiguration
    
    init(fileid: String, key: AnyHashable, configures: AsyncURLSessionConfiguration) {
        self.fileid = fileid
        self.key = key
        self.configures = configures
    }
    
    func execute(for inputValue: URLRequestBuilder) async throws -> String {
        guard let urlString = inputValue.url, let url = URL(string: urlString) else {
            throw ShellError.badURL(inputValue.url ?? "nil")
        }
        let content = try await AsyncStringParserDataTask(request: inputValue, encoding: .utf8, sessionKey: key, configures: configures).asyncValue()
        let next = try request(url, content: content).make()
        let string = try await AsyncStringParserDataTask(request: next, encoding: .utf8, sessionKey: key, configures: configures).asyncValue()
        return string
    }
    
    private func request(_ url: URL, content: String) throws -> TowerJSPageRequest {
        let (host, scheme) = try url.baseComponents()
        let prefixPath = try TowerJSPathMatch().extract(content)
        let key = try TowerJSKeyMatch().extract(content)
        let value = try TowerJSValueMatch().extract(content).asciiHexMD5String()
        let path = "\(prefixPath)\(key)&value=\(value)"
        return TowerJSPageRequest(fileid: fileid, scheme: scheme, host: host, path: path)
    }
    
    func sessionKey(_ value: AnyHashable) -> Self {
        .init(fileid: fileid, key: key, configures: configures)
    }
}

public struct TowerJSPathMatch {
    let pattern = "\"([^\\?\"]+\\?type=\\w+&key=)\""
    
    public func extract(_ text: String) throws -> String {
        try FileIDMatch(pattern).extract(text)
    }
}

public struct TowerJSKeyMatch {
    let pattern = "key=\"(\\w+)\""
    
    public func extract(_ text: String) throws -> String {
        try FileIDMatch(pattern).extract(text)
    }
}

public struct TowerJSValueMatch {
    let pattern = "value=\"(\\w+)\""
    
    public func extract(_ text: String) throws -> String {
        try FileIDMatch(pattern).extract(text)
    }
}
