//
//  File.swift
//  
//
//  Created by john on 2023/9/6.
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

public struct SignFileDownPage: Condom {
    public typealias Input = String
    public typealias Output = URLRequest
    
    public let fileid: String
    
    public init(fileid: String) {
        self.fileid = fileid
    }
    
    public func publisher(for inputValue: String) -> AnyPublisher<Output, Error> {
        Future {
            try await AsyncSignFileDownPage(fileid: fileid).execute(for: inputValue).build()
        }
        .eraseToAnyPublisher()
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
}

public struct AsyncSignFileDownPage: Dirtyware {
    public typealias Input = String
    public typealias Output = URLRequestBuilder
    
    public let fileid: String
    
    public init(fileid: String) {
        self.fileid = fileid
    }
    
    private func request(_ string: String) throws -> URLRequestBuilder {
        guard let url = URL(string: string),
                let component = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw ShellError.badURL(string)
        }
        
        guard let host = component.host, let scheme = component.scheme else {
            throw ShellError.badURL(string)
        }
        
        return DownPageCustomHeaderRequest(scheme: scheme, host: host, fileid: fileid).make({
            $0.add(value: "application/x-www-form-urlencoded", forKey: "content-type")
                .add(value: "text/plain, */*", forKey: "accept")
                .add(value: "XMLHttpRequest", forKey: "x-requested-with")
                .add(value: "en-US,en;q=0.9", forKey: "accept-language")
                .add(value: "\(scheme)://\(host)", forKey: "origin")
                .add(value: userAgent, forKey: "user-agent")
                .add(value: string, forKey: "referer")
        })
    }
    
    public func execute(for inputValue: String) async throws -> URLRequestBuilder {
        try request(inputValue)
    }
}
