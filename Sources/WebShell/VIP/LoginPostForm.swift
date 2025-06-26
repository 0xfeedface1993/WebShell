//
//  File.swift
//  WebShell
//
//  Created by york on 2025/6/24.
//

import Foundation
import Durex

public struct LoginPostForm: SessionableDirtyware {
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
        let fileURL = try await inputValue.string(.fileidURL)
        let request = try Request(url: fileURL, username: username, password: password, submitme: "1").make()
        let invalidAccount = try? await FindStringInDomSearch(.invalidPassword2, configures: configures, key: key).execute(for: request)
        guard invalidAccount == nil else {
            throw ShellError.invalidAccount(username: username)
        }
        return inputValue
            .assign(request, forKey: .lastRequest)
            .assign(invalidAccount, forKey: .output)
    }
    
    public func sessionKey(_ value: SessionKey) -> Self {
        .init(username: username, password: password, configures: configures, key: value)
    }
    
    struct Request {
        let url: String
        let username: String
        let password: String
        let submitme: String
        
        func make() throws -> URLRequestBuilder {
            let (host, scheme) = try url.baseComponents()
            let base = "\(scheme)://\(host)"
            let refer = "\(base)/account/login"
            let next = "\(base)/account/login"
            let params = [
                "submitme": submitme,
                "username": username,
                "password": password,
            ]
            let body = params
                .map({ "\($0.key)=\($0.value)" })
                .joined(separator: "&")
                .data(using: .utf8) ?? Data()
            return URLRequestBuilder(next)
                .method(.post)
                .add(value: LinkRequestHeader.generalAccept.value, forKey: LinkRequestHeader.generalAccept.key.rawValue)
                .add(value: LinkRequestHeader.urlencodedContentType.value, forKey: LinkRequestHeader.urlencodedContentType.key.rawValue)
                .add(value: userAgent, forKey: LinkRequestHeader.Key.customUserAgent.rawValue)
                .add(value: refer, forKey: LinkRequestHeader.Key.referer.rawValue)
                .add(value: base, forKey: LinkRequestHeader.Key.origin.rawValue)
                .add(value: LinkRequestHeader.enUSAcceptLanguage.value, forKey: LinkRequestHeader.enUSAcceptLanguage.key.rawValue)
                .body(body)
        }
    }
}

public enum PaidUser: Sendable, ContextValue {
    public var valueDescription: String {
        switch self {
        case .paid:
            return "paid"
        case .unpaid:
            return "unpaid"
        }
    }
    
    case paid
    case unpaid
}

public protocol PaidCatcher: Sendable {
    func isPaid(_ keyStore: KeyStore) async throws -> PaidUser
}
 
public struct PaidUserString: PaidCatcher {
    public let finder: FileIDMatch
    public let key: SessionKey
    
    public init(finder: FileIDMatch, key: SessionKey) {
        self.finder = finder
        self.key = key
    }
    
    public func isPaid(_ keyStore: KeyStore) async throws -> PaidUser {
        let configures = try await keyStore.configures(.configures)
        let request = try await Request(url: keyStore.request(.lastRequest).url ?? "").make()
        do {
            let html = try await FindStringInDomSearch(finder, configures: configures, key: key).execute(for: request)
            keyStore.assign(PaidUser.paid, forKey: .paid)
                .assign(html, forKey: .output)
            return .paid
        } catch {
            keyStore.assign(PaidUser.unpaid, forKey: .paid)
            return .unpaid
        }
    }
    
    struct Request {
        let url: String
        
        func make() throws -> URLRequestBuilder {
            let (host, scheme) = try url.baseComponents()
            let base = "\(scheme)://\(host)"
            let refer = url
            let next = "\(base)/account"
            return URLRequestBuilder(next)
                .method(.get)
                .add(value: LinkRequestHeader.generalAccept.value, forKey: LinkRequestHeader.generalAccept.key.rawValue)
                .add(value: userAgent, forKey: LinkRequestHeader.Key.customUserAgent.rawValue)
                .add(value: refer, forKey: LinkRequestHeader.Key.referer.rawValue)
        }
    }
}

public struct Paid<Catcher: PaidCatcher>: SessionableDirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public let key: SessionKey
    public var configures: AsyncURLSessionConfiguration
    public let catcher: Catcher
    
    public init(configures: AsyncURLSessionConfiguration, key: SessionKey, catcher: Catcher) {
        self.key = key
        self.configures = configures
        self.catcher = catcher
    }
    
    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        let user = try await catcher.isPaid(inputValue)
        return inputValue
            .assign(user, forKey: .paid)
            .assign(user, forKey: .output)
    }
    
    public func sessionKey(_ value: SessionKey) -> Self {
        .init(configures: configures, key: value, catcher: catcher)
    }
}
