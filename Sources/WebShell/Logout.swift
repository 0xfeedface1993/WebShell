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

public enum LogoutOptions: Sendable {
    case accountAction
    case accountLogout
    case logout
    
    var path: String {
        switch self {
        case .accountAction:
            return "account.php?action=logout"
        case .accountLogout:
            return "account/logout"
        case .logout:
            return "logout"
        }
    }
}

public struct Logout: UniversalDirtyware {
    public let configures: Durex.AsyncURLSessionConfiguration
    public let option: LogoutOptions
    
    public init(_ configures: Durex.AsyncURLSessionConfiguration, option: LogoutOptions) {
        self.configures = configures
        self.option = option
    }
    
    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        let fileIDURL = try await inputValue.string(.fileidURL)
        guard let components = URLComponents(string: fileIDURL), let scheme = components.scheme, let host = components.host else {
            throw ShellError.noPageLink
        }
        let configures = try await inputValue.configures(.configures)
        let sessionKey = try await inputValue.sessionKey(.sessionKey)
        let builder: URLRequestBuilder
        
        switch option {
        case .accountAction, .accountLogout:
            builder = URLRequestBuilder("\(scheme)://\(host)/\(option.path)")
                .method(.get)
                .add(.generalAccept)
                .add(value: userAgent, forKey: .customUserAgent)
                .add(value: host, forKey: "Host")
        case .logout:
            builder = URLRequestBuilder("\(scheme)://\(host)/\(option.path)")
                .method(.post)
                .add(.generalShortAccept)
                .add(.xmlHttpRequest)
                .add(value: try? await inputValue.string(.xsrf), forKey: .xXSRFToken)
                .add(value: "\(scheme)://\(host)", forKey: .origin)
                .add(value: userAgent, forKey: .customUserAgent)
                .add(value: "\(scheme)://\(host)/dashboard", forKey: .referer)
                .add(.zhHans)
                .add(.keepAliveConnection)
                .add(.jsonContentType)
                .body("{}".data(using: .utf8)!)
        }
        
        let url = try builder.build().url
        let (_, response) = try await DataTask(builder).configures(configures).sessionKey(sessionKey).asyncValueResponse()
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

