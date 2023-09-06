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

#if COMBINE_LINUX && canImport(CombineX)
import CombineX
#else
import Combine
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// 从html代码中获取fileid模块，规则详见``FileIDInFunctionParameter``
public struct FileIDStringInDomSearch: SessionableCondom {
    public typealias Input = URLRequest
    public typealias Output = String
    
    let finder: FileIDFinder
    public var key: AnyHashable
    
    public init(_ finder: FileIDFinder, key: AnyHashable = "default") {
        self.finder = finder
        self.key = key
    }
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        Future {
            try await AsyncFileIDStringInDomSearch(finder, configures: .shared, key: key).execute(for: .init(inputValue))
        }
        .eraseToAnyPublisher()
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
    
    public func sessionKey(_ value: AnyHashable) -> FileIDStringInDomSearch {
        FileIDStringInDomSearch(finder, key: value)
    }
}

public struct AsyncFileIDStringInDomSearch: SessionableDirtyware {
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
        let string = try await AsyncStringParserDataTask(request: inputValue, encoding: .utf8, sessionKey: key, configures: configures).asyncValue()
        return try finder.extract(string)
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        .init(finder, configures: configures, key: value)
    }
}
