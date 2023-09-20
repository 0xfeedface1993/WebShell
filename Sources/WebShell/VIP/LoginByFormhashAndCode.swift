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
    
    public var key: AnyHashable
    public var configures: AsyncURLSessionConfiguration
    public let reader: Reader
    public let username: String
    public let password: String
    public let retry: Int
    
    public init(_ username: String, password: String, configures: AsyncURLSessionConfiguration, key: AnyHashable = "default", retry: Int = 1, reader: Reader) {
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
    
    public func sessionKey(_ value: AnyHashable) -> LoginByFormhashAndCode {
        .init(username, password: password, configures: configures, key: value, retry: retry, reader: reader)
    }
}

public struct CustomLoginByFormhashAndCode<Reader: CodeReadable>: SessionableDirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public var key: AnyHashable
    public var configures: AsyncURLSessionConfiguration
    public let form: LoginForm<Reader>
    
    /// 检查是否已经登录，首先检测是否有登录状态的cookie，没有的话就发出登录请求，
    /// 登录页面检测是否有成功、已登录字样，有的话就认为登录成功，否则就认为登录失败，
    /// 如果有验证码错误的提示，就重新发出登录请求，直到登录成功或者达到最大重试次数
    public init(_ form: LoginForm<Reader>, configures: AsyncURLSessionConfiguration, key: AnyHashable = "default") {
        self.key = key
        self.configures = configures
        self.form = form
    }
    
    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        if await isCookieLogind() {
            return inputValue
        }   else    {
            return try await timesLogdin(for: inputValue)
        }
    }
    
    func timesLogdin(for inputValue: KeyStore) async throws -> KeyStore {
        var failed: Error?
        for i in 0..<form.retry {
            do {
                return try await process(for: inputValue)
            } catch {
                shellLogger.error("login failed at \(i + 1) times, error \(error)")
                failed = error
            }
        }
        throw failed ?? LoginError.unknown
    }
    
    func process(for inputValue: KeyStore) async throws -> KeyStore {
        let loging = FindStringInFile(.htmlFile, forKey: .formhash, finder: .formhash)
        let logined = FindStringInFile(.htmlFile, forKey: .output, finder: .logined)
        let store = try await LoginPage(form.querys)
            .join(URLRequestPageReader(.output, configures: configures, key: key))
            .join(ConditionsGroup(loging, logined))
            .execute(for: inputValue)
        
        guard let hash = formhash(store) else {
            return inputValue
        }
        
        guard let reader = form.reader else {
            shellLogger.info("please pass code reader")
            throw ShellError.noCodeReader
        }
        
        shellLogger.info("user not login, got formhash \(hash), try login")
        return try await CodeImageCustomPathRequest(form.codePath, configures: configures, key: key)
            .join(CodeImagePrediction(configures, key: key, reader: reader))
            .join(LoginVerifyCode(username: form.username, password: form.password, configures: configures, key: key))
            .execute(for: inputValue)
    }
    
    func formhash(_ store: KeyStore) -> String? {
        do {
            return try store.string(.formhash)
        } catch {
            shellLogger.error("formhash read failed: \(error), maybe logined? try pass it.")
            return nil
        }
    }
    
    /// 检测cookie是否已经登录
    func isCookieLogind() async -> Bool {
        if form.cookieName.isEmpty {
            shellLogger.info("cookie name is empty, skip check cookie")
            return false
        }
        
        let cookie = try? await AsyncSession(configures)
            .context(key)
            .cookies()
            .first(where: {
                $0.name == form.cookieName
            })
        
        guard let cookie = cookie else {
            shellLogger.info("user may logined, cookie \(form.cookieName) not exists")
            return false
        }
        shellLogger.info("user may logined, cookie \(form.cookieName): \(cookie) exists")
        return true
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        .init(form, configures: configures, key: value)
    }
}

/// login form
public struct LoginForm<Reader: CodeReadable> {
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
