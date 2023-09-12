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
        var failed: Error?
        for i in 0..<retry {
            do {
                return try await LoginPage()
                    .join(LoginFormhash(configures, key: key))
                    .join(CodeImageRequest(configures, key: key))
                    .join(CodeImagePrediction(configures, key: key, reader: reader))
                    .join(LoginVerifyCode(username: username, password: password, configures: configures, key: key))
                    .execute(for: inputValue)
            } catch {
                shellLogger.error("login failed at \(i + 1) times, error \(error)")
                failed = error
            }
        }
        
        throw failed ?? LoginError.unknown
    }
    
    public func sessionKey(_ value: AnyHashable) -> LoginByFormhashAndCode {
        .init(username, password: password, configures: configures, key: value, retry: retry, reader: reader)
    }
}
