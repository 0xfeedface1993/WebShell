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
    
    public var valueDescription: String {
        "\(self): \(cached)"
    }
}

public extension KeyStore.Key {
    static let formhash = KeyStore.Key("formhash")
    static let code = KeyStore.Key("code")
    static let username = KeyStore.Key("username")
    static let password = KeyStore.Key("password")
    static let lastRequest = KeyStore.Key("last_request")
    static let lastOutput = KeyStore.Key("output")
    static let sign = KeyStore.Key("sign")
    static let fileid = KeyStore.Key("fileid")
    static let fileidURL = KeyStore.Key("fileid_url")
}
