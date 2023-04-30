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
public struct Saver: Condom {
    public typealias Input = [URLRequest]
    public typealias Output = URL
    
    public enum Policy {
        /// 出现同名文件则后缀加-n
        case normal
        /// 覆盖同名文件
        case `override`
    }
    
    let policy: Policy
    
    public init(_ policy: Policy = .normal) {
        self.policy = policy
    }
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        guard let request = inputValue.first else {
            return Fail(error: ShellError.emptyRequest).eraseToAnyPublisher()
        }
        return URLSession
            .shared
            .downloadTask(request)
            .tryMap {
                try MoveToDownloads(tempURL: $0.0, suggestedFilename: $0.1.suggestedFilename, policy: policy).move()
            }
            .eraseToAnyPublisher()
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
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
            print(">>> [override] delete file at \(defaultURL)")
#endif
        }
        
        let destination = destinationURL(defaultURL)
        try FileManager.default.moveItem(at: tempURL, to: destination)
#if DEBUG
        print(">>> move file to \(destination)")
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
public struct BridgeSaver: Condom {
    public typealias Input = [URLRequest]
    public typealias Output = URL
    
    let sessionBundle: SessionBundle
    let policy: Saver.Policy
    
    public init(_ bundle: SessionBundle, policy: Saver.Policy = .normal) {
        self.policy = policy
        self.sessionBundle = bundle
    }
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        guard let request = inputValue.first else {
            return Fail(error: ShellError.emptyRequest).eraseToAnyPublisher()
        }
        return sessionBundle
            .session
            .downloadTask(request)
            .tryMap {
                try MoveToDownloads(tempURL: $0.0, suggestedFilename: $0.1.suggestedFilename, policy: policy).move()
            }
            .eraseToAnyPublisher()
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
}

public protocol URLUpdator {
    func updateURLSubject() -> PassthroughSubject<URL, Never>
}

public struct SessionBundle: URLUpdator {
    public let session: URLSession
    public let urlUpdateSubject: PassthroughSubject<URL, Never>
    
    public init(_ session: URLSession, subject: PassthroughSubject<URL, Never>) {
        self.session = session
        self.urlUpdateSubject = subject
    }
    
    public func updateURLSubject() -> PassthroughSubject<URL, Never> {
        urlUpdateSubject
    }
}
