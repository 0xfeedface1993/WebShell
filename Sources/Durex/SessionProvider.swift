//
//  File.swift
//  
//
//  Created by john on 2023/9/5.
//

import Foundation
import AnyErase

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol SessionProvider {
    /// 绑定URLSession下载任务和任务tag，用于后续任务查询
    /// - Parameters:
    ///   - task: URLSession下载任务
    ///   - tag: 任务tag
    func bind(task: URLSessionDownloadTask, tagHashValue: Int)
    
    /// 解除URLSession下载任务和任务tag的绑定，下载任务结束后解除绑定
    /// - Parameter task: URLSession下载任务
    func unbind(task: URLSessionDownloadTask)
    
    /// 系统原始的URLSession
    func systemSession() -> URLSession
    
    /// 匹配下载任务id
    /// - Parameter task: URLSession下载任务
    /// - Returns: 任务id
    func tag(for task: URLSessionDownloadTask) -> Int
    
    /// 匹配下载任务id
    /// - Parameter task: URLSession下载任务taskIdentifier
    /// - Returns: 任务id
    func tag(for taskIdentifier: Int) -> Int
    
    /// 根据任务id查下载任务taskIdentifier
    /// - Parameter tag: 任务id
    /// - Returns: taskIdentifier
    func taskIdentifier(for tag: Int) -> Int?
}

public protocol AsyncSessionProvider {
    typealias HashValue = any Hashable
    typealias TaskIdentifier = Int
    
    /// 绑定URLSession下载任务和任务tag，用于后续任务查询
    /// - Parameters:
    ///   - task: URLSession下载任务
    ///   - tag: 任务tag
    func bind(task: TaskIdentifier, tag: HashValue) async
    
    /// 解除URLSession下载任务和任务tag的绑定，下载任务结束后解除绑定
    /// - Parameter task: URLSession下载任务
    func unbind(task: TaskIdentifier) async
    
    func unbind(tag: HashValue) async
    
    /// 系统原始的URLSession
    func client() -> URLClient
    
    /// 匹配下载任务id
    /// - Parameter task: URLSession下载任务taskIdentifier
    /// - Returns: 任务id
    func tag(for taskIdentifier: TaskIdentifier) async -> HashValue
    
    /// 根据任务id查下载任务taskIdentifier
    /// - Parameter tag: 任务id
    /// - Returns: taskIdentifier
    func taskIdentifier(for tag: HashValue) async -> TaskIdentifier?
}
