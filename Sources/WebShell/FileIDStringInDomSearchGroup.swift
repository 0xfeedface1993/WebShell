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

/// 合并FileIDStringInDomSearch和GeneralDownPageBy两个模块，因后者需要前者的输入链接生成refer，
/// 此模块减少复杂度，后续使用
public struct FileIDStringInDomSearchGroup: SessionableCondom {
    public typealias Input = URLRequest
    public typealias Output = URLRequest
    
    let finder: FileIDFinder
    public var key: AnyHashable
    
    public init(_ finder: FileIDFinder, key: AnyHashable = "default") {
        self.finder = finder
        self.key = key
    }
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        do {
            return try search(inputValue)
                .publisher(for: inputValue)
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
    
    private func search(_ request: URLRequest) throws -> AnyCondom<Input, Output> {
        guard let url = request.url,
                let component = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw ShellError.badURL(request.url?.absoluteString ?? "")
        }
        
        guard let host = component.host, let scheme = component.scheme else {
            throw ShellError.badURL(url.absoluteString)
        }
        
        let searchid = FileIDStringInDomSearch(finder, key: key)
        let page = GeneralDownPageByID(scheme: scheme, host: host, refer: url.absoluteString)
        
        return searchid.join(page)
    }
    
    public func sessionKey(_ value: AnyHashable) -> FileIDStringInDomSearchGroup {
        FileIDStringInDomSearchGroup(finder, key: value)
    }
}

public struct AsyncFileIDStringInDomSearchGroup: SessionableDirtyware {
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
        guard let url = request.url, let next = URL(string: url),
                let component = URLComponents(url: next, resolvingAgainstBaseURL: false) else {
            throw ShellError.badURL(request.url ?? "")
        }
        
        guard let host = component.host, let scheme = component.scheme else {
            throw ShellError.badURL(next.absoluteString)
        }
        
        let searchid = AsyncFileIDStringInDomSearch(finder, configures: configures, key: key)
        let page = AsyncGeneralDownPageByID(scheme: scheme, host: host, refer: next.absoluteString)
        
        return searchid.join(page)
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        .init(finder, configures: configures, key: value)
    }
}
