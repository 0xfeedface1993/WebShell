//
//  File.swift
//  
//
//  Created by john on 2023/9/7.
//

import Foundation

#if canImport(Durex)
import Durex
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct StringParserDataTask {
    let request: URLRequestBuilder
    let encoding: String.Encoding
    let sessionKey: any Hashable
    let configures: Durex.AsyncURLSessionConfiguration
    
    func asyncValue() async throws -> String {
        let key = sessionKey
        let data = try await DataTask(request).configures(configures).sessionKey(key).asyncValue()
        guard let text = String(data: data, encoding: encoding) else {
            throw ShellError.decodingFailed(encoding)
        }
        
        let maxCount = 100
        let display = text.count > maxCount ? String(text[..<text.index(text.startIndex, offsetBy: maxCount)]):text
        shellLogger.info("utf8 text: \(display)")
        
        if text.count > maxCount {
            Task {
                let tmp = FileManager.default.temporaryDirectory
                let file = tmp.appendingPathComponent("\(UUID().uuidString).txt")
                do {
                    try data.write(to: file)
                } catch {
                    shellLogger.error("cache text data faild at \(file), full text: \(text)")
                }
            }
        }
        
        return text
    }
    
    init(request: URLRequestBuilder, encoding: String.Encoding, sessionKey: any Hashable, configures: Durex.AsyncURLSessionConfiguration) {
        self.request = request
        self.encoding = encoding
        self.sessionKey = sessionKey
        self.configures = configures
    }
    
    init(_ request: URLRequestBuilder) {
        self.request = request
        self.encoding = .utf8
        self.sessionKey = "default"
        self.configures = .shared
    }
    
    func encoding(_ value: String.Encoding) -> Self {
        .init(request: request, encoding: value, sessionKey: sessionKey, configures: configures)
    }
    
    func sessionKey(_ value: any Hashable) -> Self {
        .init(request: request, encoding: encoding, sessionKey: value, configures: configures)
    }
    func configures(_ value: AsyncURLSessionConfiguration) -> Self {
        .init(request: request, encoding: encoding, sessionKey: sessionKey, configures: value)
    }
    
    func request(_ value: URLRequestBuilder) -> Self {
        .init(request: value, encoding: encoding, sessionKey: sessionKey, configures: configures)
    }
}

public struct DataTask {
    let request: URLRequestBuilder
    let sessionKey: any Hashable
    let configures: Durex.AsyncURLSessionConfiguration
    
    func asyncValue() async throws -> Data {
        let key = sessionKey
        let context = try await AsyncSession(configures).context(key)
        let data = try await context.data(with: request)
        shellLogger.info("data downloaded: \(data.count)")
        return data
    }
    
    init(request: URLRequestBuilder, sessionKey: any Hashable, configures: Durex.AsyncURLSessionConfiguration) {
        self.request = request
        self.sessionKey = sessionKey
        self.configures = configures
    }
    
    init(_ request: URLRequestBuilder) {
        self.request = request
        self.sessionKey = "default"
        self.configures = .shared
    }
    
    func sessionKey(_ value: any Hashable) -> Self {
        .init(request: request, sessionKey: value, configures: configures)
    }
    func configures(_ value: AsyncURLSessionConfiguration) -> Self {
        .init(request: request, sessionKey: sessionKey, configures: value)
    }
    
    func request(_ value: URLRequestBuilder) -> Self {
        .init(request: value, sessionKey: sessionKey, configures: configures)
    }
}
