//
//  File.swift
//  WebShell
//
//  Created by york on 2025/6/24.
//

import Foundation
import Durex
import hmjs

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
        let string = try await StringParserDataTask(request: request, encoding: .utf8, sessionKey: key, configures: configures).asyncValue()
        let invalidAccount = try? FileIDMatch.invalidPassword2.extract(string)
        guard invalidAccount == nil else {
            throw ShellError.invalidAccount(username: username)
        }
        await updateHMCookies(string, fileURL: fileURL, key: key, configures: configures, store: inputValue)
        return inputValue
            .assign(username, forKey: .username)
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
                .add(.generalAccept)
                .add(.urlencodedContentType)
                .add(value: userAgent, forKey: .customUserAgent)
                .add(value: refer, forKey: .referer)
                .add(value: base, forKey: .origin)
                .add(.enUSAcceptLanguage)
                .body(body)
        }
    }
}

func updateHMCookies(
    _ html: String,
    fileURL: String,
    key: SessionKey,
    configures: AsyncURLSessionConfiguration,
    store: KeyStore
) async {
    do {
        let hmsrc = try FileIDMatch.hmsrc.extract(html)
        let (host, scheme) = try fileURL.baseComponents()
        let hmRequest = URLRequestBuilder(hmsrc)
            .add(.allAccept)
            .add(value: "\(scheme)://\(host)", forKey: .referer)
            .add(.customUserAgent)
        let hmjs = try await StringParserDataTask(request: hmRequest, encoding: .utf8, sessionKey: key, configures: configures).asyncValue()
        let oldLvt = try? await store.string(.lvt)
        let oldIpvt = try? await store.string(.lpvt)
        let (lvt, lpvt, cookies) = try updateHmCookies(js: hmjs, existingLvt: oldLvt, existingLpvt: oldIpvt)
        shellLogger.info("update lvt: \(oldLvt ?? "nil") -> \(lvt), lpvt: \(oldIpvt ?? "nil") -> \(lpvt)")
        store.assign(lvt, forKey: .lvt)
        store.assign(lpvt, forKey: .lpvt)
        try await AsyncSession(store.configures(.configures))
            .context(store.sessionKey(.sessionKey))
            .mergeCookies(cookies)
    } catch {
        shellLogger.error("update hm cookies failed, \(error)")
    }
}
