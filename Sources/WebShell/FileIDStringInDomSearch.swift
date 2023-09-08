//
//  File.swift
//  
//
//  Created by john on 2023/9/6.
//

import Foundation

#if canImport(Durex)
import Durex
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// 从html代码中获取fileid模块，规则详见``FileIDInFunctionParameter``
public struct FileIDStringInDomSearch: SessionableDirtyware {
    public typealias Input = URLRequestBuilder
    public typealias Output = String
    
    let finder: FileIDFinder
    public var key: AnyHashable
    public let configures: AsyncURLSessionConfiguration
    
    public init(_ finder: FileIDFinder, configures: AsyncURLSessionConfiguration, key: AnyHashable = "default") {
        self.finder = finder
        self.key = key
        self.configures = configures
    }
    
    public func execute(for inputValue: URLRequestBuilder) async throws -> String {
        let string = try await StringParserDataTask(request: inputValue, encoding: .utf8, sessionKey: key, configures: configures).asyncValue()
        return try finder.extract(string)
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        .init(finder, configures: configures, key: value)
    }
}
