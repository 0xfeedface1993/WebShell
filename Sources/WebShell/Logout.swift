//
//  File.swift
//  WebShell
//
//  Created by york on 2025/6/19.
//

import Foundation
import Durex

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct Logout: Dirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public let configures: Durex.AsyncURLSessionConfiguration
    
    public init(_ configures: Durex.AsyncURLSessionConfiguration) {
        self.configures = configures
    }
    
    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        let fileIDURL = try await inputValue.string(.fileidURL)
        guard let components = URLComponents(string: fileIDURL), let scheme = components.scheme, let host = components.host else {
            throw ShellError.noPageLink
        }
        let configures = try await inputValue.configures(.configures)
        let builder = URLRequestBuilder("\(scheme)://\(host)/account.php?action=logout")
            .method(.get)
            .add(value: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forKey: "accept")
            .add(value: userAgent, forKey: "user-agent")
            .add(value: host, forKey: "Host")
        let url = try builder.build().url
        let (_, response) = try await configures.defaultSession.download(with: builder)
        guard let response = response as? HTTPURLResponse else {
            return inputValue
        }
        if let url {
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: response.allHeaderFields as? [String: String] ?? [:], for: url)
            if !cookies.isEmpty {
                shellLogger.info("logout cookies: \(cookies)")
            }
        }
        return inputValue
    }
}

