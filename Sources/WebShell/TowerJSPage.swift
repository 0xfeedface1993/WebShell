//
//  File.swift
//  
//
//  Created by john on 2023/8/5.
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

public struct TowerJSPage: SessionableCondom {
    public typealias Input = String
    
    public typealias Output = URLRequest
    
    public let key: AnyHashable
    
    public func publisher(for inputValue: String) -> AnyPublisher<URLRequest, Error> {
        pagePublisher(inputValue)
            .tryMap {
                try url($0, url: inputValue)
            }
            .eraseToAnyPublisher()
    }
    
    public func empty() -> AnyPublisher<URLRequest, Error> {
        Empty().eraseToAnyPublisher()
    }
    
    private func fileid(_ string: String) throws -> String {
        try FileIDMatch.default.extract(string)
    }
    
    private func pageRequest(_ string: String) throws -> TowerFilePageRequest {
        let fileid = try fileid(string)
        let (host, scheme) = try string.baseComponents()
        return TowerFilePageRequest(fileid: fileid, scheme: scheme, host: host)
    }
    
    private func url(_ content: String, url: String) throws -> URLRequest {
        let relatePath = try TowerJSMatch().extract(content)
        let fileid = try fileid(url)
        let (host, scheme) = try url.baseComponents()
        return try TowerJSPageRequest(fileid: fileid, scheme: scheme, host: host, path: relatePath).make()
    }
    
    private func pagePublisher(_ string: String) -> AnyPublisher<String, Error> {
        do {
            return StringParserDataTask(request: try pageRequest(string).make(), encoding: .utf8, sessionKey: key)
                .publisher()
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    public init(_ key: AnyHashable = "default") {
        self.key = key
    }
    
    public func sessionKey(_ value: AnyHashable) -> TowerJSPage {
        .init(value)
    }
}

public struct TowerFilePageRequest {
    let fileid: String
    let scheme: String
    let host: String
    
    func make() throws -> URLRequest {
        let http = "\(scheme)://\(host)"
        let url = "\(http)/file-\(fileid).html"
        return try URLRequestBuilder(url)
            .method(.get)
            .add(value: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forKey: "accept")
            .add(value: userAgent, forKey: "user-agent")
            .add(value: "en-US,en;q=0.9", forKey: "accept-language")
            .build()
    }
}

public struct TowerJSPageRequest {
    let fileid: String
    let scheme: String
    let host: String
    let path: String
    
    func make() throws -> URLRequest {
        let http = "\(scheme)://\(host)"
        let url = "\(http)\(path)"
        let referURL = "\(http)/file-\(fileid).html"
        return try URLRequestBuilder(url)
            .method(.get)
            .add(value: "*/*", forKey: "accept")
            .add(value: userAgent, forKey: "user-agent")
            .add(value: "en-US,en;q=0.9", forKey: "accept-language")
            .add(value: referURL, forKey: "referer")
            .build()
    }
}

public struct TowerJSMatch {
    let pattern = "src=\"([^\"]+)\"\\>"
    
    public func extract(_ text: String) throws -> String {
        try FileIDMatch(pattern).extract(text)
    }
}
