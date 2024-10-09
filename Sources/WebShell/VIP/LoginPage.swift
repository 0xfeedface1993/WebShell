//
//  File.swift
//  
//
//  Created by john on 2023/9/10.
//

import Foundation
import Durex

public struct LoginPage: Dirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    let querys: [String: String]
    
    public init(_ query: [String: String] = [
        "action": "login",
        "ref": "/mydisk.php?item=profile&menu=cp"
    ]) {
        self.querys = query
    }
    
    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        let url = try await inputValue.string(.fileidURL)
        let request = try Request(url: url, querys: querys).make()
        return inputValue.assign(request, forKey: .output)
    }
    
    struct Request {
        let url: String
        let querys: [String: String]
        
        func make() throws -> URLRequestBuilder {
            let (host, scheme) = try url.baseComponents()
            let refer = "\(scheme)://\(host)"
            let suffix: String
            if querys.count > 0 {
                suffix = "?" + querys.map({ "\($0.key)=\($0.value)" }).joined(separator: "&")
            }   else  {
                suffix = ""
            }
            let next = "\(refer)/account.php\(suffix)"
            return URLRequestBuilder(next)
                .method(.get)
                .add(value: fullAccept, forKey: "accept")
                .add(value: userAgent, forKey: "user-agent")
                .add(value: refer, forKey: "referer")
                .add(value: "en-US,en;q=0.9", forKey: "accept-language")
                .add(value: "keep-alive", forKey: "Connection")
        }
    }
}
