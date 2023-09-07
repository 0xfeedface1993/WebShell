//
//  Saver.swift
//  WebShellExsample
//
//  Created by john on 2023/3/29.
//  Copyright © 2023 ascp. All rights reserved.
//

#if canImport(Durex)
import Durex
#endif
import Foundation
#if COMBINE_LINUX && canImport(CombineX)
import CombineX
#else
import Combine
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// 从多个下载下载链接中下载文件, 保存到`Downloads`目录，目前只使用第一个链接
public struct Saver: SessionableCondom {
    public typealias Input = [URLRequest]
    public typealias Output = URL
    
    public enum Policy {
        /// 出现同名文件则后缀加-n
        case normal
        /// 覆盖同名文件
        case `override`
    }
    
    let policy: Policy
    public var key: AnyHashable
    
    public init(_ policy: Policy = .normal, key: AnyHashable = "default") {
        self.policy = policy
        self.key = key
    }
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        Future {
            try await AsyncSaver(policy, configures: .shared, key: key).execute(for: inputValue.map(URLRequestBuilder.init(_:)))
        }
        .eraseToAnyPublisher()
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
    
    public func sessionKey(_ value: AnyHashable) -> Saver {
        Saver(policy, key: value)
    }
}

public struct AsyncSaver: SessionableDirtyware {
    public typealias Input = [URLRequestBuilder]
    public typealias Output = URL
    
    let policy: Saver.Policy
    public var key: AnyHashable
    public let configures: AsyncURLSessionConfiguration
    
    public init(_ policy: Saver.Policy = .normal, configures: AsyncURLSessionConfiguration, key: AnyHashable = "default") {
        self.policy = policy
        self.key = key
        self.configures = configures
    }
    
    public func execute(for inputValue: Input) async throws -> Output {
        guard let request = inputValue.first else {
            throw ShellError.emptyRequest
        }
        
        let context = try await AsyncSession(configures).context(key)
        let states = try await context.downloadWithProgress(request, tag: key)
        for try await state in states {
            switch state.value {
            case .state(let value):
                shellLogger.info("download task \(value.identifier) progress \(value.progress.fractionCompleted)")
                continue
            case .file(let file):
                let next = try MoveToDownloads(tempURL: file.url, suggestedFilename: file.response.suggestedFilename, policy: policy).move()
                return next
            case .error(let failure):
                shellLogger.info("download task \(failure.identifier) failed, \(failure.error)")
                throw failure.error
            }
        }
        shellLogger.info("Ooops! download task unexcepted finished")
        throw DownloadSessionRawError.unknown
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        .init(policy, configures: configures, key: value)
    }
}

public struct MoveToDownloads {
    /// 临时文件
    let tempURL: URL
    /// 文件名
    let suggestedFilename: String?
    /// 覆写模式
    let policy: Saver.Policy
    
    func move() throws -> URL {
        guard FileManager.default.fileExists(atPath: tempURL.path) else {
            throw ShellError.fileNotExist(tempURL)
        }
        
        let filename = suggestedFilename ?? tempURL.lastPathComponent
        guard let folder = FileManager.default.urls(for: .downloadsDirectory, in: .allDomainsMask).first else {
            throw ShellError.invalidDestination
        }
        
        let defaultURL = folder.appendingPathComponent(filename)
        if policy == .override, FileManager.default.fileExists(atPath: defaultURL.path) {
            try FileManager.default.removeItem(at: defaultURL)
#if DEBUG
            shellLogger.info("[override] delete file at \(defaultURL)")
#endif
        }
        
        let destination = destinationURL(defaultURL)
        try FileManager.default.moveItem(at: tempURL, to: destination)
#if DEBUG
        shellLogger.info("move file to \(destination)")
#endif
        return destination
    }
    
    func destinationURL(_ url: URL) -> URL {
        let manager = FileManager.default
        let filename = suggestedFilename ?? url.lastPathComponent
        let folder = url.deletingLastPathComponent()
        var count = 1
        var next = url
        while manager.fileExists(atPath: next.path) {
            let parts = filename.components(separatedBy: ".")
            if parts.count > 1 {
                let nextName = (["\(parts[0])-\(count)"] + Array(parts.dropFirst())).joined(separator: ".")
                next = folder.appendingPathComponent(nextName)
            }   else    {
                next = folder.appendingPathComponent("\(filename)-\(count)")
            }
            count += 1
        }
        return next
    }
}
