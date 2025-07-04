//
//  File.swift
//  
//
//  Created by john on 2023/9/10.
//

import Foundation
import Durex

public enum LoginError: Error {
    case invalidCode
    case invalidPassword
    case unknown
}

public struct LoginVerifyCode: SessionableDirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public let username: String
    public let password: String
    public let key: SessionKey
    public var configures: AsyncURLSessionConfiguration
    
    public init(username: String, password: String, configures: AsyncURLSessionConfiguration, key: SessionKey) {
        self.username = username
        self.password = password
        self.key = key
        self.configures = configures
    }
    
    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        let lastRequest = try await inputValue.request(.lastRequest)
        let code = try await inputValue.string(.code)
        let formhash = try await inputValue.string(.formhash)
        let request = try Request(url: lastRequest.url ?? "", username: username, password: password, code: code, formhash: formhash).make()
        return try await ExternalValueReader(request, forKey: .output)
            .join(URLRequestPageReader(.output, configures: configures, key: key))
            .join(
                FindStringInFile(.htmlFile, forKey: .output, finder: FileIDMatch.logined)
                    .or(
                        FindStringInFile(.htmlFile, forKey: .output, finder: FileIDMatch.invalidCode)
                            .throw({ _ in LoginError.invalidCode })
                    )
                    .or(
                        FindStringInFile(.htmlFile, forKey: .output, finder: FileIDMatch.invalidPassword)
                            .throw({ _ in LoginError.invalidPassword })
                    )
            )
            .map { value in
                value.assign(request, forKey: .lastRequest)
            }
            .execute(for: inputValue)
    }
    
    public func sessionKey(_ value: SessionKey) -> Self {
        .init(username: username, password: password, configures: configures, key: value)
    }
    
    struct Request {
        let url: String
        let username: String
        let password: String
        let code: String
        let formhash: String
        
        func make() throws -> URLRequestBuilder {
            let (host, scheme) = try url.baseComponents()
            let base = "\(scheme)://\(host)"
            let refer = "\(base)/account.php?action=login"
            let next = "\(base)/account.php"
            let params = ["action": "login",
                        "task": "login",
                        "ref": base.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "",
                        "formhash": formhash,
                        "verycode": code,
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
