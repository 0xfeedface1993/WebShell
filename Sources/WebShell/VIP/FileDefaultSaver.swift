//
//  File.swift
//  
//
//  Created by john on 2023/9/12.
//

import Foundation
import Durex

public struct FileDefaultSaver: SessionableDirtyware {
    public typealias Input = KeyStore
    public typealias Output = URL
    
    public let policy: Saver.Policy
    public var key: AnyHashable
    public var configures: AsyncURLSessionConfiguration
    
    public init(_ policy: Saver.Policy, configures: AsyncURLSessionConfiguration, key: AnyHashable) {
        self.key = key
        self.configures = configures
        self.policy = policy
    }
    
    public func execute(for inputValue: KeyStore) async throws -> URL {
        let requests = try inputValue.requests(.output)
        for url in requests {
            do {
                return try await downloadFile(url)
            }   catch   {
                shellLogger.error("download file [\(url.url ?? "Ooops!")] failed, try next one. \(error)")
                throw error
            }
        }
        throw ShellError.emptyRequest
    }
    
    private func downloadFile(_ url: URLRequestBuilder) async throws -> URL {
        let context = try await AsyncSession(configures).context(key)
        let states = try await context.downloadWithProgress(url, tag: key)
        var news: TaskNews?
        
        // 在for-in loop内抛出错误则会影响其他地方的监听 导致只有一个接受者收到错误信息
        for try await state in states {
            if case .error(_) = state.value {
                news = state.value
                break
            }
            if case .file(_) = state.value {
                news = state.value
                break
            }
        }
        
        guard let news = news else {
            shellLogger.info("Ooops! download task unexcepted finished")
            throw DownloadSessionRawError.unknown
        }
        
        return try result(news)
    }
    
    private func result(_ news: TaskNews) throws -> URL {
        switch news {
        case .state(_):
            shellLogger.info("Ooops! download task unexcepted finished")
            throw DownloadSessionRawError.unknown
        case .file(let file):
            let next = try MoveToDownloads(tempURL: file.url, suggestedFilename: file.response.suggestedFilename, policy: policy).move()
            return next
        case .error(let failure):
            shellLogger.info("download task \(failure.identifier) failed, \(failure.error)")
            throw failure.error
        }
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        .init(policy, configures: configures, key: value)
    }
}
