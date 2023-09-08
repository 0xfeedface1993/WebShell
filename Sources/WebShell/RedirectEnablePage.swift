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

public struct RedirectEnablePage: SessionableDirtyware {
    public typealias Input = String
    public typealias Output = String
    
    public var key: AnyHashable
    public let configures: Durex.AsyncURLSessionConfiguration
    
    public init(_ configures: Durex.AsyncURLSessionConfiguration, key: AnyHashable = "default") {
        self.key = key
        self.configures = configures
    }
    
    public func execute(for inputValue: String) async throws -> String {
        let request = try JustRequest(url: inputValue).make()
        let context = try await AsyncSession(configures).context(key)
        let (_, response) = try await context.download(with: request)
        if let redirectURL = validRedirectResponse(response, request: request.url) {
            return redirectURL.absoluteString
        }
        return inputValue
    }
    
    private func validRedirectResponse(_ value: URLResponse, request: String?) -> URL? {
        guard let url = value.url, let origin = request, let originURL = URL(string: origin), value.url != originURL else {
            return nil
        }
        return url
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        .init(configures, key: value)
    }
}
