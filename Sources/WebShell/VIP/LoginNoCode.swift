//
//  File.swift
//  
//
//  Created by john on 2023/9/19.
//

import Foundation
import Durex

public struct LoginNoCode: SessionableDirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public let username: String
    public let password: String
    public var key: AnyHashable
    public var configures: AsyncURLSessionConfiguration
    
    public init(username: String, password: String, configures: AsyncURLSessionConfiguration, key: AnyHashable) {
        self.username = username
        self.password = password
        self.key = key
        self.configures = configures
    }
    
    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        let lastRequest = try inputValue.request(.lastRequest)
        let formhash = try inputValue.string(.formhash)
        let request = try Request(url: lastRequest.url ?? "", username: username, password: password, formhash: formhash).make()
        let finder = FileIDMatch.logined
        do {
            let html = try await FindStringInDomSearch(finder, configures: configures, key: key).execute(for: request)
            return inputValue
                .assign(request, forKey: .lastRequest)
                .assign(html, forKey: .output)
        } catch {
            throw error
        }
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        .init(username: username, password: password, configures: configures, key: value)
    }
    
    struct Request {
        let url: String
        let username: String
        let password: String
        let formhash: String
        
        func make() throws -> URLRequestBuilder {
            let (host, scheme) = try url.baseComponents()
            let base = "\(scheme)://\(host)"
            let refer = "\(base)/account.php?action=login"
            let next = "\(base)/account.php?action=login"
            let params = ["action": "fastlogin",
                        "task": "login",
                        "ref": "",
                        "formhash": formhash,
                        "username": username,
                        "password": password,
            ]
            let body = params
                .map({ "\($0.key)=\($0.value)" })
                .joined(separator: "&")
                .data(using: .utf8) ?? Data()
            return URLRequestBuilder(next)
                .method(.post)
                .add(value: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forKey: "accept")
                .add(value: "application/x-www-form-urlencoded", forKey: "content-type")
                .add(value: userAgent, forKey: "user-agent")
                .add(value: refer, forKey: "referer")
                .add(value: base, forKey: "origin")
                .add(value: "en-US,en;q=0.9", forKey: "accept-language")
                .add(value: "keep-alive", forKey: "Connection")
                .body(body)
        }
    }
}
