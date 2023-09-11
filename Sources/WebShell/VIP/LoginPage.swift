//
//  File.swift
//  
//
//  Created by john on 2023/9/10.
//

import Foundation
import Durex

public struct LoginPage: Dirtyware {
    public typealias Input = String
    public typealias Output = KeyStore
    
    public func execute(for inputValue: String) async throws -> KeyStore {
        let request = try Request(url: inputValue).make()
        return KeyStore().assign(request, forKey: .lastOutput)
    }
    
    struct Request {
        let url: String
        
        func make() throws -> URLRequestBuilder {
            let (host, scheme) = try url.baseComponents()
            let refer = "\(scheme)://\(host)"
            let next = "\(refer)/account.php?action=login&ref=/mydisk.php?item=profile&menu=cp"
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
