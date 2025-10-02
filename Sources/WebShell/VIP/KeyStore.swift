//
//  File.swift
//  
//
//  Created by john on 2023/9/12.
//

import Foundation
import Durex

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum KeyStoreError: Error {
    case valueTransformTypeIncorrect
}

@globalActor
public actor KeyStoreActor {
    public static let shared = KeyStoreActor()
}

public final class KeyStore: ContextValue {
    public struct Key: Hashable, Sendable, CustomStringConvertible {
        public enum Base: Hashable, Sendable {
            case string(String)
            case int(Int)
            case int64(Int64)
        }
        
        let base: Base
        
        public init(_ base: Base) {
            self.base = base
        }
        
        public init(_ text: String) {
            self.base = .string(text)
        }
        
        public var description: String {
            "\(self.base)"
        }
    }
    
    enum Wrapped: Sendable {
        case instance(ContextValue)
        case array([ContextValue])
    }
    
    @KeyStoreActor
    private var cached = [Key: Wrapped]()
    
    public init() { }
    
    @discardableResult
    public func assign<T>(_ value: T, forKey key: Key) -> Self where T: ContextValue {
        Task { @KeyStoreActor in
            cached[key] = .instance(value)
        }
        return self
    }
    
    @discardableResult
    public func assign(_ value: [ContextValue], forKey key: Key) -> Self {
        Task { @KeyStoreActor in
            cached[key] = .array(value)
        }
        return self
    }
    
    @discardableResult
    public func assign(_ value: (any ContextValue)?, forKey key: Key) -> Self {
        Task { @KeyStoreActor in
            if let value {
                cached[key] = .instance(value)
            } else {
                cached.removeValue(forKey: key)
            }
        }
        return self
    }
    
    @KeyStoreActor
    public func value<T>(forKey key: Key) -> T? {
        let wrapped = cached[key]
        switch wrapped {
        case .array(let items):
            return items as? T
        case .instance(let value):
            return value as? T
        case .none:
            return nil
        }
    }
    
    @KeyStoreActor
    public func take<T>(forKey key: Key) throws -> T {
        guard let next: T = value(forKey: key) else {
            shellLogger.error("no key [\("\(key)")] store as \(T.self), maybe \(String(describing: self.cached[key]))")
            throw KeyStoreError.valueTransformTypeIncorrect
        }
        return next
    }
    
    @inlinable
    @KeyStoreActor
    public func string(_ key: Key) throws -> String {
        try take(forKey: key)
    }
    
    @inlinable
    @KeyStoreActor
    public func strings(_ key: Key) throws -> [String] {
        try take(forKey: key)
    }
    
    @inlinable
    @KeyStoreActor
    public func request(_ key: Key) throws -> URLRequestBuilder {
        try take(forKey: key)
    }
    
    @inlinable
    @KeyStoreActor
    public func requests(_ key: Key) throws -> [URLRequestBuilder] {
        try take(forKey: key)
    }
    
    @inlinable
    @KeyStoreActor
    public func url(_ key: Key) throws -> URL {
        try take(forKey: key)
    }
    
    @inlinable
    @KeyStoreActor
    public func configures(_ key: Key) throws -> AsyncURLSessionConfiguration {
        try take(forKey: key)
    }
    
    @inlinable
    @KeyStoreActor
    public func sessionKey(_ key: Key) throws -> SessionKey {
        try take(forKey: key)
    }
    
    @KeyStoreActor
    public var valueDescription: String {
        "\(self): \(cached)"
    }
    
    @inlinable
    @KeyStoreActor
    public func cookies(_ key: Key) throws -> [HTTPCookie] {
        try take(forKey: key)
    }
    
    @inlinable
    @KeyStoreActor
    public func cookie(_ key: Key) throws -> HTTPCookie {
        try take(forKey: key)
    }
}

public extension KeyStore.Key {
    /// 登录页面formhash
    static let formhash = KeyStore.Key("formhash")
    /// 验证码
    static let code = KeyStore.Key("code")
    /// 登录用户名
    static let username = KeyStore.Key("username")
    /// 登录密码
    static let password = KeyStore.Key("password")
    /// 上一个模块发起的网络请求
    static let lastRequest = KeyStore.Key("last_request")
    /// 上一个模块输出的数据
    static let output = KeyStore.Key("output")
    /// 下载文件的sign值
    static let sign = KeyStore.Key("sign")
    /// 下载文件id
    static let fileid = KeyStore.Key("fileid")
    /// 包含下载文件id的url
    static let fileidURL = KeyStore.Key("fileid_url")
    /// 上一个网络请求获取的html文件
    static let htmlFile = KeyStore.Key("html_file")
//    /// 上一个网络请求获取的html文本
//    static let htmlString = KeyStore.Key("html_string")
    /// 当前网络相关配置
    static let configures = KeyStore.Key("configures")
    static let paid = KeyStore.Key("paid")
    static let sessionKey = KeyStore.Key("session_key")
    
    static let xsrf = KeyStore.Key("xsrf")
    static let csrf = KeyStore.Key("csrf")
    static let setCookies = KeyStore.Key("set_cookies")
    static let jsonUser = KeyStore.Key("json_user")
    static let lvt = KeyStore.Key("lvt")
    static let lpvt = KeyStore.Key("lpvt")
}

/// Set instant value to new key store
public struct ValueReader<T: ContextValue>: Dirtyware {
    public typealias Input = T
    public typealias Output = KeyStore
    
    public let key: KeyStore.Key
    
    public init(_ key: KeyStore.Key) {
        self.key = key
    }
    
    public func execute(for inputValue: Input) async throws -> KeyStore {
        KeyStore().assign(inputValue, forKey: key)
    }
}

/// Set instant value to current key store
public struct ExternalValueReader<T>: Dirtyware where T: ContextValue {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public let key: KeyStore.Key
    public let value: T
    
    public init(_ value: T, forKey key: KeyStore.Key) {
        self.key = key
        self.value = value
    }
    
    public func execute(for inputValue: Input) async throws -> KeyStore {
        inputValue.assign(value, forKey: key)
    }
}

/// Copy output value to new place in key store
public struct EraseOutValue: Dirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public let key: KeyStore.Key
    
    public init(to key: KeyStore.Key) {
        self.key = key
    }
    
    public func execute(for inputValue: Input) async throws -> KeyStore {
        try await CopyOutValue(.output, to: key).execute(for: inputValue)
    }
}

/// Copy value between key in key store
public struct CopyOutValue: Dirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public let to: KeyStore.Key
    public let from: KeyStore.Key
    
    public init(_ from: KeyStore.Key, to key: KeyStore.Key) {
        self.to = key
        self.from = from
    }
    
    @KeyStoreActor
    public func execute(for inputValue: Input) async throws -> KeyStore {
        let output: ContextValue? = inputValue.value(forKey: from)
        return inputValue.assign(output, forKey: to)
    }
}
