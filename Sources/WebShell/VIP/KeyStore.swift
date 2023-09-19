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
}
