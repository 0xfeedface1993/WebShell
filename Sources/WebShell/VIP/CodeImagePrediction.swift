//
//  File.swift
//  
//
//  Created by john on 2023/9/12.
//

import Foundation
import Durex

/// 验证码下载、识别
public struct CodeImagePrediction<Reader: CodeReadable>: SessionableDirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public var key: AnyHashable
    public var configures: AsyncURLSessionConfiguration
    public let reader: Reader
    
    public init(_ configures: AsyncURLSessionConfiguration, key: AnyHashable = "default", reader: Reader) {
        self.key = key
        self.configures = configures
        self.reader = reader
    }
    
    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        let lastRequest = try inputValue.request(.output)
        let data = try await DataTask(request: lastRequest, sessionKey: key, configures: configures).asyncValue()
        let code = try await reader.code(data)
        guard code.count == 4 else {
            throw ShellError.invalidCode(code)
        }
        return inputValue.assign(code, forKey: .code)
            .assign(lastRequest, forKey: .lastRequest)
            .assign(code, forKey: .output)
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        .init(configures, key: value, reader: reader)
    }
}
