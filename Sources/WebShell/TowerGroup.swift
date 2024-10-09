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

public struct TowerGroup: SessionableDirtyware {
    public typealias Input = String
    public typealias Output = URLRequestBuilder
    
    public let action: String
    public let key: SessionKey
    public let configures: Durex.AsyncURLSessionConfiguration
    
    public init(_ action: String, configures: Durex.AsyncURLSessionConfiguration, key: SessionKey = .host("default")) {
        self.action = action
        self.key = key
        self.configures = configures
    }
    
    public func sessionKey(_ value: SessionKey) -> Self {
        .init(action, configures: configures, key: value)
    }
    
    private func fileid(_ string: String) throws -> String {
        try FileIDMatch.default.extract(string)
    }
    
    public func execute(for inputValue: String) async throws -> URLRequestBuilder {
        let fileid = try fileid(inputValue)
        return try await TowerJSPage(configures, key: key)
            .join(TowerFileListRequestGeneratorGroup(fileid, action: action, configures: configures, key: key))
            .execute(for: inputValue)
    }
}
