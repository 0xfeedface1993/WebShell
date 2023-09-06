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

/// 使用自定义URLSession下载模块
public struct BridgeSaver: SessionableCondom {
    public typealias Input = [URLRequest]
    public typealias Output = URL
    
    public var key: AnyHashable = "default"
    let sessionBundle: SessionBundle
    let policy: Saver.Policy
    let tag: Int?
    
    public init(_ bundle: SessionBundle, policy: Saver.Policy = .normal, tag: Int? = nil) {
        self.policy = policy
        self.sessionBundle = bundle
        self.tag = tag
        self.key = sessionBundle.sessionKey
    }
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        Future {
            try await AsyncBridgeSaver(sessionBundle, policy: policy, configures: .shared, tag: tag).execute(for: inputValue.map(URLRequestBuilder.init(_:)))
        }
        .eraseToAnyPublisher()
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
    
    public func sessionKey(_ value: AnyHashable) -> BridgeSaver {
        BridgeSaver(.init(value), policy: policy, tag: tag)
    }
}

public struct AsyncBridgeSaver: SessionableDirtyware {
    public typealias Input = [URLRequestBuilder]
    public typealias Output = URL
    
    public var key: AnyHashable = "default"
    let sessionBundle: SessionBundle
    let policy: Saver.Policy
    let tag: AnyHashable
    public let configures: AsyncURLSessionConfiguration
    
    public init(_ bundle: SessionBundle, policy: Saver.Policy = .normal, configures: AsyncURLSessionConfiguration, tag: AnyHashable) {
        self.policy = policy
        self.sessionBundle = bundle
        self.tag = tag
        self.key = sessionBundle.sessionKey
        self.configures = configures
    }
    
    public func execute(for inputValue: [URLRequestBuilder]) async throws -> URL {
        guard let request = inputValue.first else {
            throw ShellError.emptyRequest
        }
        
        let context = try await AsyncSession(configures).context(key)
        let progress = try await context.downloadWithProgress(request, tag: tag)
        var news: TaskNews?
        for try await state in progress {
            switch state.value {
            case .state(_):
                continue
            case .file(_):
                news = state.value
            case .error(let error):
                throw error.error
            }
        }
        guard let news = news, let next = try moveToDownloadsFolder(news) else {
            throw ShellError.invalidDestination
        }
        return next
    }
    
    private func moveToDownloadsFolder(_ update: TaskNews) throws -> URL? {
        guard case .file(let value) = update else {
            return nil
        }
        return try MoveToDownloads(tempURL: value.url, suggestedFilename: value.response.suggestedFilename, policy: policy).move()
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        .init(.init(value), policy: policy, configures: configures, tag: tag)
    }
}
