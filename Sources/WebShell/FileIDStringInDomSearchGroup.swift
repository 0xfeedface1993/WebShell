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

public struct FileIDStringInDomSearchGroup: SessionableDirtyware {
    public typealias Input = URLRequestBuilder
    public typealias Output = URLRequestBuilder
    
    let finder: FileIDFinder
    public var key: AnyHashable
    public var configures: AsyncURLSessionConfiguration
    
    public init(_ finder: FileIDFinder, configures: AsyncURLSessionConfiguration, key: AnyHashable = "default") {
        self.finder = finder
        self.key = key
        self.configures = configures
    }
    
    public func execute(for inputValue: URLRequestBuilder) async throws -> URLRequestBuilder {
        try await search(inputValue).execute(for: inputValue)
    }
    
    private func search(_ request: URLRequestBuilder) throws -> AnyDirtyware<Input, Output> {
        guard let url = request.url else {
            throw ShellError.badURL(request.url ?? "")
        }
        
        let (host, scheme) = try url.baseComponents()
        let searchid = FindStringInDomSearch(finder, configures: configures, key: key)
        let page = GeneralDownPageByID(scheme: scheme, host: host, refer: url)
        
        return searchid.join(page)
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        .init(finder, configures: configures, key: value)
    }
}
