//
//  File.swift
//  
//
//  Created by john on 2023/5/1.
//

import Foundation
import Combine
#if canImport(AnyErase)
import AnyErase
#endif
import os.log

public protocol CustomURLSession {
    /// 下载数据，下载后的数据会转换成Data，大数据下载推荐使用``download(with:)``方法
    /// - Parameter request: 网络请求
    /// - Returns: 异步数据
    func data(with request: URLRequest) -> AnyPublisher<Data, Error>
    
    /// 下载文件，文件存储在临时区域，拿到URL后进行复制或者移动
    /// - Parameter request: 下载文件请求
    /// - Returns: 异步文件URL
    func download(with request: URLRequest) -> AnyPublisher<(URL, URLResponse), Error>
    
    /// 下载文件, 包含进度信息更新、下载完成、失败
    /// - Parameter request: 下载文件请求
    /// - Returns: 异步文件进度+文件URL
    func downloadWithProgress(_ request: URLRequest, tag: AnyHashable?) -> DownloadURLProgressPublisher
    
    /// 其他模块想要获取当前下载任务的进度、完成通知则使用此方法获取Publisher,
    /// 注意：此Publisher不会finished，终止的情况只会是error，所以只要监听receiveValue和error即可。
    /// - Parameter identifier: 下载任务唯一key，使用它的hashValue
    /// - Returns: 任务状态
    func downloadNews(for identifier: AnyHashable) -> AnyPublisher<UpdateNews, Error>
    
    /// 其他模块想要获取当前下载任务的进度、完成通知则使用此方法获取Publisher,
    /// 注意：此Publisher不会finished，也不会出现error，所以只要监听receiveValue，抛出的错误就是`.error()`枚举。
    /// - Parameter identifier: 下载任务唯一key，使用它的hashValue
    /// - Returns: 任务状态
    func downloadWrapNews(for identifier: AnyHashable) -> AnyPublisher<UpdateNews, Never>
    
    /// 其他模块想要获取所有下载任务的进度、完成通知则使用此方法获取Publisher,
    /// - Returns: 任务状态
    func downloadNews() -> AnyPublisher<UpdateNews, Never>
}

extension CustomURLSession {
    /// 全局共享下载session
    /// - Returns: 共享session
    static func shared() -> CustomURLSession {
        DownloadSession._shared
    }
}

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

public final class DownloadSession: CustomURLSession {
    fileprivate static let _shared = DownloadSession()
    private let delegator = URLSessionDelegator()
    private lazy var _session = CookieMaster(delegator)
    private var tagsCached = [Int: Int]()
    private let lock = Lock()
    
    public init() {
        
    }
    
    deinit {
        lock.cleanupLock()
    }
    
    public func downloadWithProgress(_ request: URLRequest, tag: AnyHashable? = nil) -> DownloadURLProgressPublisher {
        DownloadURLProgressPublisher(request: request, session: self, tag: tag?.hashValue)
    }
    
    public func download(with request: URLRequest) -> AnyPublisher<(URL, URLResponse), Error> {
        DownloadURLPublisher(request: request, session: _session.session)
            .eraseToAnyPublisher()
    }
    
    public func data(with request: URLRequest) -> AnyPublisher<Data, Error> {
        download(with: request)
            .tryMap { url in
                try Data(contentsOf: url.0)
            }
            .eraseToAnyPublisher()
    }
    
    public func downloadNews(for identifier: AnyHashable) -> AnyPublisher<UpdateNews, Error> {
        delegator.news(self, tag: identifier.hashValue)
            .map {
                UpdateNews(value: $0, tagHashValue: identifier.hashValue)
            }
            .eraseToAnyPublisher()
    }
    
    public func downloadWrapNews(for identifier: AnyHashable) -> AnyPublisher<UpdateNews, Never> {
        delegator.news(self, tag: identifier.hashValue)
            .map {
                UpdateNews(value: $0, tagHashValue: identifier.hashValue)
            }
            .eraseToAnyPublisher()
    }
    
    public func downloadNews() -> AnyPublisher<UpdateNews, Never> {
        delegator.news()
            .map {
                UpdateNews(value: $0, tagHashValue: self.tag(for: $0.identifier))
            }
            .eraseToAnyPublisher()
    }
}

extension DownloadSession: SessionProvider {
    public func systemSession() -> URLSession {
        _session.session
    }
    
    public func bind(task: URLSessionDownloadTask, tagHashValue: Int) {
        lock.lock()
        let identifier = task.taskIdentifier
        let value = tagsCached[identifier]
        tagsCached[identifier] = tagHashValue
        lock.unlock()
        if let value = value {
            logger.info("download task \(identifier) already has tag \(value)")
        }
        logger.info("download task \(identifier) add new tag \(tagHashValue)")
    }
    
    public func unbind(task: URLSessionDownloadTask) {
        lock.lock()
        let identifier = task.taskIdentifier
        tagsCached.removeValue(forKey: identifier)
        lock.unlock()
        logger.info("download task \(identifier) remove tag")
    }
    
    @inlinable
    public func tag(for task: URLSessionDownloadTask) -> Int {
        tag(for: task.taskIdentifier)
    }
    
    public func tag(for taskIdentifier: Int) -> Int {
        lock.lock()
        let identifier = taskIdentifier
        let value = tagsCached[identifier]
        lock.unlock()
//        if let value = value {
//            os_log(.debug, log: logger, "download task %d retrive tag %d", identifier, value)
//        }   else    {
//            os_log(.debug, log: logger, "download task %d has no tag", identifier)
//        }
        return value ?? identifier
    }
    
    public func taskIdentifier(for tag: Int) -> Int? {
        lock.lock()
        let value = tagsCached.first(where: { $0.value == tag })?.key
        lock.unlock()
//        if let value = value {
//            os_log(.debug, log: logger, "download tag %d retrive task %d", tag, value)
//        }   else    {
//            os_log(.debug, log: logger, "download tag %d has no task", tag)
//        }
        return value
    }
}
