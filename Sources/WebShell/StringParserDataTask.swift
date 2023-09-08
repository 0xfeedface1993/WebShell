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
        let context = try await AsyncSession(configures).context(sessionKey)
        let data = try await context.data(with: request)
        guard let text = String(data: data, encoding: encoding) else {
            throw ShellError.decodingFailed(encoding)
        }
        shellLogger.info("utf8 text: \(text)")
        return text
    }
}
