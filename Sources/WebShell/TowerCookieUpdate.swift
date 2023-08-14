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
    typealias Input = URLRequest
    typealias Output = String
    
    let fileid: String
    let key: AnyHashable
    
    func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        StringParserDataTask(request: inputValue, encoding: .utf8, sessionKey: key)
            .publisher()
            .tryMap { content in
                guard let url = inputValue.url else {
                    throw ShellError.badURL(inputValue.url?.absoluteString ?? "")
                }
                return try request(url, content: content).make()
            }
            .flatMap({ request in
                StringParserDataTask(request: request, encoding: .utf8, sessionKey: key)
                    .publisher()
            })
            .eraseToAnyPublisher()
    }
    
    func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
    
    private func request(_ url: URL, content: String) throws -> TowerJSPageRequest {
        let (host, scheme) = try url.baseComponents()
        let prefixPath = try TowerJSPathMatch().extract(content)
        let key = try TowerJSKeyMatch().extract(content)
        let value = try TowerJSValueMatch().extract(content).asciiHexMD5String()
        let path = "\(prefixPath)\(key)&value=\(value)"
        return TowerJSPageRequest(fileid: fileid, scheme: scheme, host: host, path: path)
    }
    
    func sessionKey(_ value: AnyHashable) -> TowerCookieUpdate {
        .init(fileid: fileid, key: value)
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
