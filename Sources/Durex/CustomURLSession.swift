//
//  File.swift
//  
//
//  Created by john on 2023/9/5.
//

import Foundation

#if COMBINE_LINUX && canImport(CombineX)
import CombineX
#else
import Combine
#endif

#if canImport(AnyErase)
import AnyErase
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import AsyncExtensions

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

public protocol AsyncCustomURLSession {
    /// 唯一标识符, 标识对象唯一，不同的实例应该是不同的的UUID
    var id: UUID { get }
    
    /// 下载数据，下载后的数据会转换成Data，大数据下载推荐使用``download(with:)``方法
    /// - Parameter request: 网络请求
    /// - Returns: 异步数据
    func data(with request: URLRequestBuilder) async throws -> Data
    
    /// 下载文件，文件存储在临时区域，拿到URL后进行复制或者移动
    /// - Parameter request: 下载文件请求
    /// - Returns: 异步文件URL
    func download(with request: URLRequestBuilder) async throws -> (URL, URLResponse)
    
    /// 下载文件, 包含进度信息更新、下载完成、失败
    /// - Parameter request: 下载文件请求
    /// - Returns: 异步文件进度+文件URL
    func downloadWithProgress<TagValue: Hashable>(_ request: URLRequestBuilder, tag: TagValue) async throws -> AnyAsyncSequence<AsyncUpdateNews>
    
    func downloadNews<TagValue: Hashable>(_ tag: TagValue) -> AnyAsyncSequence<AsyncUpdateNews>
    
    /// 其他模块想要获取所有下载任务的进度、完成通知则使用此方法获取Publisher,
    /// - Returns: 任务状态
    func downloadNews() -> AnyAsyncSequence<AsyncUpdateNews>
    
    /// 读取设置Cookies缓存到请求的header内
    func requestBySetCookies(with request: URLRequestBuilder) throws -> URLRequestBuilder
    
    /// 获取当前的所有cookie
    func cookies() -> [HTTPCookie]
    
    /// 取消当前下载中的任务，如果任务不存在不会抛出错误，取消任务失败才会抛出错误
    func cancel<TagValue: Hashable>(_ tag: TagValue) async throws
}
