//
//  File.swift
//  
//
//  Created by john on 2023/9/6.
//

import Foundation

#if canImport(Durex)
import Durex
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct RawDownPage: Dirtyware {
    public typealias Input = String
    public typealias Output = URLRequestBuilder
    
    public let fileid: String
    
    public init(fileid: String) {
        self.fileid = fileid
    }
    
    public func execute(for inputValue: String) async throws -> URLRequestBuilder {
        try request(inputValue)
    }
    
    private func request(_ string: String) throws -> URLRequestBuilder {
        guard let url = URL(string: string),
                let component = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw ShellError.badURL(string)
        }
        
        guard let host = component.host, let scheme = component.scheme else {
            throw ShellError.badURL(string)
        }
        
        return try DownPageRequest(refer: string, scheme: scheme, host: host, fileid: fileid).make()
    }
}

public struct DownPageRequest {
    let refer: String
    let scheme: String
    let host: String
    let fileid: String
    
    func make() throws -> URLRequestBuilder {
        let http = "\(scheme)://\(host)"
        let url = "\(http)/down-\(fileid).html"
        return URLRequestBuilder(url)
            .add(value: "1", forKey: "Upgrade-Insecure-Requests")
            .add(value: fullAccept, forKey: "Accept")
            .add(value: "zh-CN,zh-Hans;q=0.9", forKey: "Accept-Language")
            .add(value: userAgent, forKey: "User-Agent")
            .add(value: refer, forKey: "Referer")
    }
}
