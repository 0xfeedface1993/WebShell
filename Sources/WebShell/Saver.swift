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
import Combine

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
        guard let request = inputValue.first else {
            return Fail(error: ShellError.emptyRequest).eraseToAnyPublisher()
        }
        
        return SessionPool
            .context(key)
            .flatMap({ context in
                context.download(with: request)
            })
            .tryMap {
                try MoveToDownloads(tempURL: $0.0, suggestedFilename: $0.1.suggestedFilename, policy: policy).move()
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
            logger.info("[override] delete file at \(defaultURL)")
#endif
        }
        
        let destination = destinationURL(defaultURL)
        try FileManager.default.moveItem(at: tempURL, to: destination)
#if DEBUG
        logger.info("move file to \(destination)")
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
        guard let request = inputValue.first else {
            return Fail(error: ShellError.emptyRequest).eraseToAnyPublisher()
        }
        
        return SessionPool
            .context(key)
            .flatMap { $0.downloadWithProgress(request, tag: tag) }
            .tryMap(moveToDownloadsFolder(_:))
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
    
    private func moveToDownloadsFolder(_ update: TaskNews) throws -> URL? {
        guard case .file(let value) = update else {
            return nil
        }
        return try MoveToDownloads(tempURL: value.url, suggestedFilename: value.response.suggestedFilename, policy: policy).move()
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
    
    public func sessionKey(_ value: AnyHashable) -> BridgeSaver {
        BridgeSaver(.init(value), policy: policy, tag: tag)
    }
}

//public protocol URLUpdator {
//    typealias Output = DownloadURLProgressPublisher.News.State
//    func updateURLSubject() -> PassthroughSubject<Output, Never>
//}

public struct SessionBundle {
//    public let session: URLSession
//    public let urlUpdateSubject: PassthroughSubject<URL, Never>
//
//    public init(_ session: URLSession, subject: PassthroughSubject<URL, Never>) {
//        self.session = session
//        self.urlUpdateSubject = subject
//    }
//
//    public func updateURLSubject() -> PassthroughSubject<URL, Never> {
//        urlUpdateSubject
//    }
    public let sessionKey: AnyHashable
//    public let urlUpdateSubject: PassthroughSubject<Output, Never>
    
    public init(_ sessionKey: AnyHashable) {
        self.sessionKey = sessionKey
    }
}
