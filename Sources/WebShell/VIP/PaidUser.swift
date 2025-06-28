//
//  File.swift
//  WebShell
//
//  Created by york on 2025/6/28.
//

import Foundation
import Durex

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

extension PaidUserString {
    public enum URLPath: Sendable {
        case account
        case mydisk
        case userMy
        case modules
        
        var linkPath: String {
            switch self {
            case .account:
                return "account"
            case .mydisk:
                return "mydisk.php?item=profile&menu=cp"
            case .userMy:
                return "user/my"
            case .modules:
                return "modules"
            }
        }
    }
}
 
public struct PaidUserString: PaidCatcher {
    public let finder: FileIDMatch
    public let key: SessionKey
    public let path: URLPath
    
    public init(finder: FileIDMatch, path: URLPath, key: SessionKey) {
        self.finder = finder
        self.key = key
        self.path = path
    }
    
    public func isPaid(_ keyStore: KeyStore) async throws -> PaidUser {
        let configures = try await keyStore.configures(.configures)
        let request = try await Request(url: keyStore.request(.lastRequest).url ?? "", path: path).make()
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
        let path: URLPath
        
        func make() throws -> URLRequestBuilder {
            let (host, scheme) = try url.baseComponents()
            let base = "\(scheme)://\(host)"
            let refer = url
            let next = "\(base)/\(path.linkPath)"
            return URLRequestBuilder(next)
                .method(.get)
                .add(value: LinkRequestHeader.generalAccept.value, forKey: LinkRequestHeader.generalAccept.key.rawValue)
                .add(value: userAgent, forKey: LinkRequestHeader.Key.customUserAgent.rawValue)
                .add(value: refer, forKey: LinkRequestHeader.Key.referer.rawValue)
        }
    }
}

public struct FreeUserString: PaidCatcher {
    public let finder: FileIDMatch
    public let key: SessionKey
    public let path: PaidUserString.URLPath
    
    public init(finder: FileIDMatch, path: PaidUserString.URLPath, key: SessionKey) {
        self.finder = finder
        self.key = key
        self.path = path
    }
    
    public func isPaid(_ keyStore: KeyStore) async throws -> PaidUser {
        let configures = try await keyStore.configures(.configures)
        let request = try await PaidUserString.Request(url: keyStore.request(.lastRequest).url ?? "", path: path).make()
        let html = try await FindStringInDomSearch(finder, configures: configures, key: key).execute(for: request)
        keyStore.assign(PaidUser.unpaid, forKey: .paid)
            .assign(html, forKey: .output)
        return .unpaid
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

public struct PaidGuard<W: PaidCatcher>: Dirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public let executor: Paid<W>
    
    public init(_ executor: Paid<W>) {
        self.executor = executor
    }
    
    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        guard let user: PaidUser? = try await executor.execute(for: inputValue).value(forKey: .paid), user == .paid else {
            inputValue.assign(PaidUser.unpaid, forKey: .paid)
            let username = (try? await inputValue.string(.username)) ?? "unknown"
            throw ShellError.unpaidUser(username: username)
        }
        return inputValue
            .assign(user, forKey: .paid)
            .assign(user, forKey: .output)
    }
}
