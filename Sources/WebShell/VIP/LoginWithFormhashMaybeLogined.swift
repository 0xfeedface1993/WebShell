//
//  File.swift
//  
//
//  Created by john on 2023/9/19.
//

import Foundation
import Durex

/// Request login page, and get formhash, if formhash is empty, means user already logined, pass it.
/// If formhash is not empty, means user not logined, try login.
public struct LoginWithFormhashMaybeLogined: SessionableDirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public let username: String
    public let password: String
    public var key: AnyHashable
    public var configures: AsyncURLSessionConfiguration
    
    public init(_ username: String, password: String, configures: AsyncURLSessionConfiguration, key: AnyHashable = "default") {
        self.key = key
        self.configures = configures
        self.username = username
        self.password = password
    }
    
    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        let loging = FindStringInFile(.htmlFile, forKey: .formhash, finder: .formhash)
        let logined = FindStringInFile(.htmlFile, forKey: .output, finder: .logined)
        let store = try await URLRequestPageReader(.output, configures: configures, key: key)
            .join(ConditionsGroup(loging, logined))
            .execute(for: inputValue)
        
        if let hash = formhash(store) {
            shellLogger.info("user not login, got formhash \(hash), try login")
            return try await LoginNoCode(username: username, password: password, configures: configures, key: key)
                .execute(for: store)
        } else {
            return inputValue
        }
    }
    
    func formhash(_ store: KeyStore) -> String? {
        do {
            return try store.string(.formhash)
        } catch {
            shellLogger.error("formhash read failed: \(error), mybe logined? try pass it.")
            return nil
        }
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        .init(username, password: password, configures: configures, key: value)
    }
}
