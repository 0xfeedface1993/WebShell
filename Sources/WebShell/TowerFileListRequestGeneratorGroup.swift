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

public struct TowerFileListRequestGeneratorGroup: SessionableDirtyware {
    public typealias Input = URLRequestBuilder
    public typealias Output = URLRequestBuilder
    
    public let fileid: String
    public let action: String
    public var key: AnyHashable
    public let configures: AsyncURLSessionConfiguration
    
    public init(_ fileid: String, action: String, configures: AsyncURLSessionConfiguration, key: AnyHashable = "default") {
        self.fileid = fileid
        self.action = action
        self.key = key
        self.configures = configures
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        .init(fileid, action: action, configures: configures, key: value)
    }
    
    public func execute(for inputValue: URLRequestBuilder) async throws -> URLRequestBuilder {
        try await TowerCookieUpdate(fileid: fileid, key: key, configures: configures)
            .join(TowerFileListRequestGenerator(fileid, action: action, url: inputValue.url ?? "", key: key))
            .execute(for: inputValue)
    }
}
