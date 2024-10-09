//
//  File.swift
//
//
//  Created by john on 2023/9/12.
//

import Foundation
import Durex

public struct LoginByFormhashAndCode<Reader: CodeReadable>: SessionableDirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public let key: SessionKey
    public var configures: AsyncURLSessionConfiguration
    public let reader: Reader
    public let username: String
    public let password: String
    public let retry: Int
    
    public init(_ username: String, password: String, configures: AsyncURLSessionConfiguration, key: SessionKey = .host("default"), retry: Int = 1, reader: Reader) {
        self.key = key
        self.configures = configures
        self.reader = reader
        self.retry = max(1, retry)
        self.username = username
        self.password = password
    }
    
    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        try await CustomLoginByFormhashAndCode(
            LoginForm(username: username,
                      password: password,
                      retry: retry,
                      reader: reader,
                      codePath: "includes/imgcode.inc.php?verycode_type=2",
                      cookieName: "", querys: [
                        "action": "login",
                        "ref": "/mydisk.php?item=profile&menu=cp"
                      ]),
            configures: configures, key: key)
        .execute(for: inputValue)
    }
    
    public func sessionKey(_ value: SessionKey) -> LoginByFormhashAndCode {
        .init(username, password: password, configures: configures, key: value, retry: retry, reader: reader)
    }
}

public struct CustomLoginByFormhashAndCode<Reader: CodeReadable>: SessionableDirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public let key: SessionKey
    public var configures: AsyncURLSessionConfiguration
    public let form: LoginForm<Reader>
    
    /// 检查是否已经登录，首先检测是否有登录状态的cookie，没有的话就发出登录请求，
    /// 登录页面检测是否有成功、已登录字样，有的话就认为登录成功，否则就认为登录失败，
    /// 如果有验证码错误的提示，就重新发出登录请求，直到登录成功或者达到最大重试次数
    public init(_ form: LoginForm<Reader>, configures: AsyncURLSessionConfiguration, key: SessionKey = .host("default")) {
        self.key = key
        self.configures = configures
        self.form = form
    }
    
    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        try await process(for: inputValue)
    }
    
    func process(for inputValue: KeyStore) async throws -> KeyStore {
        guard let reader = form.reader else {
            shellLogger.info("please pass code reader")
            throw ShellError.noCodeReader
        }
        return try await LoginPage(form.querys)
            .join(URLRequestPageReader(.output, configures: configures, key: key))
            .join(
                FindStringInFile(.htmlFile, forKey: .formhash, finder: .formhash)
                    .or(FindStringInFile(.htmlFile, forKey: .output, finder: .logined))
            )
            .join(
                CodeImageCustomPathRequest(form.codePath, configures: configures, key: key)
                .join(CodeImagePrediction(configures, key: key, reader: reader))
                .join(LoginVerifyCode(username: form.username, password: form.password, configures: configures, key: key))
                .if(exists: .formhash)
            )
            .retry(3)
            .maybe({ value, task in
                if form.cookieName.isEmpty {
                    return true
                } else {
                    let next = (try? await value.configures(.configures).defaultSession.cookies().contains(where: { $0.name == form.cookieName }))
                    return !(next ?? false)
                }
            })
            .execute(for: inputValue)
    }
    
    public func sessionKey(_ value: SessionKey) -> Self {
        .init(form, configures: configures, key: value)
    }
}

/// login form
public struct LoginForm<Reader: CodeReadable>: Sendable {
    /// username
    public let username: String
    /// password
    public let password: String
    /// login request retry times, dut to network error or verify code recognition failed
    public let retry: Int
    /// verify code reader
    public let reader: Reader?
    /// verify code image url path, no host
    public let codePath: String
    /// logined cookie name
    public let cookieName: String
    public let querys: [String: String]
    
    public init(username: String, password: String, retry: Int, reader: Reader?, codePath: String, cookieName: String, querys: [String: String]) {
        self.username = username
        self.password = password
        self.retry = max(retry, 1)
        self.reader = reader
        self.codePath = codePath
        self.cookieName = cookieName
        self.querys = querys
    }
    
    public init(_ username: String) {
        self.init(username: username, password: "", retry: 1, reader: nil, codePath: "", cookieName: "", querys: [:])
    }
    
    public func username(_ value: String) -> Self {
        .init(username: value, password: password, retry: retry, reader: reader, codePath: codePath, cookieName: cookieName, querys: querys)
    }
    
    public func password(_ value: String) -> Self {
        .init(username: username, password: value, retry: retry, reader: reader, codePath: codePath, cookieName: cookieName, querys: querys)
    }
    
    public func retry(_ value: Int) -> Self {
        .init(username: username, password: password, retry: max(value, 1), reader: reader, codePath: codePath, cookieName: cookieName, querys: querys)
    }
    
    public func reader(_ value: Reader) -> Self {
        .init(username: username, password: password, retry: retry, reader: value, codePath: codePath, cookieName: cookieName, querys: querys)
    }
    
    public func codePath(_ value: String) -> Self {
        .init(username: username, password: password, retry: retry, reader: reader, codePath: value, cookieName: cookieName, querys: querys)
    }
    
    public func cookieName(_ value: String) -> Self {
        .init(username: username, password: password, retry: retry, reader: reader, codePath: codePath, cookieName: value, querys: querys)
    }

    public func querys(_ value: [String: String]) -> Self {
        .init(username: username, password: password, retry: retry, reader: reader, codePath: codePath, cookieName: cookieName, querys: value)
    }
}
