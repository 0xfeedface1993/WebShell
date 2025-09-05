//
//  File.swift
//  WebShell
//
//  Created by york on 2025/8/31.
//

import Foundation
import Durex
import SwiftSoup

public struct LoginXSRFVerifyCode: SessionableDirtyware {
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
        let xsrf = try await inputValue.cookie(.xsrf).value.removingPercentEncoding ?? ""
        let csrf = try await inputValue.string(.csrf)
        let request = try Request(url: lastRequest.url ?? "", username: username, password: password, code: code, tokenXSRF: xsrf, tokenCSRF: csrf).make()
        return try await ExternalValueReader(request, forKey: .output)
            .join(URLRequestPageReader(.output, configures: configures, key: key))
            .join(DataPartTransformer())
            .map { store in
                let json: LoginedResponse = try await decode(store)
                let state = LoginState(json.props)
                switch state {
                case .invalidAccount:
                    throw LoginError.invalidPassword
                case .invalidPassword:
                    throw LoginError.invalidPassword
                case .invalidCaptcha:
                    throw LoginError.invalidCode
                case .logined(let user):
                    inputValue.assign(user, forKey: .jsonUser)
                }
            }
            .join(ExtractCSXFCookie())
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
        let tokenXSRF: String
        let tokenCSRF: String
        
        struct Form: Codable {
            let login: String
            let password: String
            let captcha: String
            let remember: Bool
        }
        
        func make() throws -> URLRequestBuilder {
            let (host, scheme) = try url.baseComponents()
            let base = "\(scheme)://\(host)"
            let refer = "\(base)/login"
            let next = "\(base)/login"
            let params = Form(login: username, password: password, captcha: code, remember: false)
            let body = try JSONEncoder().encode(params)
            return URLRequestBuilder(next)
                .method(.post)
                .add(.generalShortAccept)
                .add(.jsonContentType)
                .add(value: userAgent, forKey: .customUserAgent)
                .add(value: refer, forKey: .referer)
                .add(value: base, forKey: .origin)
                .add(.zhHans)
                .add(value: tokenXSRF, forKey: .xXSRFToken)
                .add(value: tokenCSRF, forKey: .xCSRFToken)
                .add(.xmlHttpRequest)
                .add(.keepAliveConnection)
                .body(body)
        }
    }
    
    public struct PreRequest {
        public let url: String
        public let tokenXSRF: String?
        public let tokenCSRF: String?
        
        public func make() throws -> URLRequestBuilder {
            let (host, scheme) = try url.baseComponents()
            let base = "\(scheme)://\(host)"
            let next = "\(base)/login"
            return URLRequestBuilder(next)
                .method(.get)
                .add(.generalShortAccept)
                .add(value: userAgent, forKey: .customUserAgent)
                .add(.zhHans)
                .add(value: tokenXSRF, forKey: .xXSRFToken)
                .add(value: tokenCSRF, forKey: .xCSRFToken)
                .add(.keepAliveConnection)
        }
        
        public init(url: String, tokenXSRF: String?, tokenCSRF: String?) {
            self.url = url
            self.tokenXSRF = tokenXSRF
            self.tokenCSRF = tokenCSRF
        }
        
        public init(store: KeyStore) async throws {
            try await self.init(
                url: store.string(.fileidURL),
                tokenXSRF: try? await store.cookie(.xsrf).value.removingPercentEncoding,
                tokenCSRF: try? await store.string(.csrf)
            )
        }
    }
}

public struct ExtractCSXFCookie: UniversalDirtyware {
    public init() { }
    
    public func execute(for inputValue: Input) async throws -> Output {
        if let responseXSRF = try await inputValue.cookies(.setCookies).first(where: { $0.name == "XSRF-TOKEN" }) {
            inputValue.assign(responseXSRF, forKey: .xsrf)
        }
        
        _ = try? await FindStringInFile(
            .htmlFile,
            forKey: .csrf,
            finder: .csrfMetaToken
        ).execute(for: inputValue)
        
        return inputValue
    }
}

public struct XSRFPaidUser: PaidCatcher {
    public init() {}
    
    public func isPaid(_ keyStore: KeyStore) async throws -> PaidUser {
        let user: LoginXSRFVerifyCode.SimpleUser? = await keyStore.value(forKey: .jsonUser)
        return user?.is_vip ?? false ? .paid:.unpaid
    }
}

public struct DataPartTransformer: UniversalDirtyware {
    let optional: Bool
    
    public init(optional: Bool = true) {
        self.optional = optional
    }
    
    public func execute(for store: KeyStore) async throws -> KeyStore {
        do {
            let url = try await store.url(.htmlFile)
            let dataPart = try await parseHTML(store)
            try await overrideFile(url, store: store, dataPart: dataPart)
            return store
        } catch {
            shellLogger.error("read data-page failed: \(error)")
            if optional {
                return store
            }
            throw ShellError.dataPartTransform
        }
    }
    
    private func parseHTML(_ store: KeyStore) async throws -> String {
        let url = try await store.url(.htmlFile)
        let data = try Data(contentsOf: url)
        let html = try SwiftSoup.parse(data)
        guard let dataPage = try html.select("#app").first()?.attr("data-page") else {
            shellLogger.warning("no data-page part! - \(url)")
            return ""
        }
        return dataPage
    }
    
    private func overrideFile(_ url: URL, store: KeyStore, dataPart: String) async throws {
        try? FileManager.default.removeItem(at: url)
        try dataPart.write(to: url, atomically: true, encoding: .utf8)
        shellLogger.info("override data-page at: \(url)")
        store.assign(url, forKey: .htmlFile)
    }
}
