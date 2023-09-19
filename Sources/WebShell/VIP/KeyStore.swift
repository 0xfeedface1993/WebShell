//
//  File.swift
//  
//
//  Created by john on 2023/9/12.
//

import Foundation
import Durex

public enum KeyStoreError: Error {
    case valueTransformTypeIncorrect
}

public final class KeyStore: ContextValue {
    public struct Key: Hashable {
        let base: AnyHashable
        
        public init<T: Hashable>(_ base: T) {
            self.base = AnyHashable(base)
        }
    }
    
    private var cached = [Key: Any]()
    
    @discardableResult
    public func assign<T>(_ value: T, forKey key: Key) -> Self {
        cached[key] = value
        return self
    }
    
    public func value<T>(forKey key: Key) -> T? {
        cached[key] as? T
    }
    
    public func take<T>(forKey key: Key) throws -> T {
        guard let next: T = value(forKey: key) else {
            shellLogger.error("no key [\(key)] store as \(T.self), maybe \(String(describing: cached[key]))")
            throw KeyStoreError.valueTransformTypeIncorrect
        }
        return next
    }
    
    public func string(_ key: Key) throws -> String {
        try take(forKey: key)
    }
    
    public func request(_ key: Key) throws -> URLRequestBuilder {
        try take(forKey: key)
    }
    
    public func requests(_ key: Key) throws -> [URLRequestBuilder] {
        try take(forKey: key)
    }
    
    public func url(_ key: Key) throws -> URL {
        try take(forKey: key)
    }
    
    public var valueDescription: String {
        "\(self): \(cached)"
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
public struct ExternalValueReader<T>: Dirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public let key: KeyStore.Key
    public let value: T
    
    public init(_ value: T, forKey key: KeyStore.Key) {
        self.key = key
        self.value = value
    }
    
    public func execute(for inputValue: Input) async throws -> KeyStore {
        inputValue.assign(inputValue, forKey: key)
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
    
    public func execute(for inputValue: Input) async throws -> KeyStore {
        let output: Any? = inputValue.value(forKey: from)
        return inputValue.assign(output, forKey: to)
    }
}
