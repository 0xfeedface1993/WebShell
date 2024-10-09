//
//  File.swift
//  
//
//  Created by john on 2023/9/5.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import AsyncExtensions

public struct AsyncURLSessionConfiguration: Sendable {
    /// 文件临时存放目录，注意需要定时清除测量，或者使用系统tmp目录`FileManager.default.temporaryDirectory`
    var cacheFolder: URL
//    /// session缓存，不同的站点使用不同的session防止互相影响，后续可以考虑使用cookies独立缓存替代
//    var sessionPool: AsyncSessionPool
    var resourcesPool: ResoucesPool
    /// 默认session缓存，不匹配的时候使用此缓存
    public let defaultSession: any AsyncCustomURLSession
    public let defaultDownloadDelegate: any AsyncURLSessiobDownloadDelegate
    /// 运行时URLDownloadTask的taskIdentifier和任务tag缓存，下载模块的回调才能识别哪个任务对应哪个task，完成下载、进度更新、取消下载、错误才能通知外部
    var tagsTaskIdenfier: any TaskIdentifiable
    
    public static let shared = create()
    
    init(cacheFolder: URL, resourcesPool: ResoucesPool, defaultSession: any AsyncCustomURLSession, defaultDownloadDelegate: any AsyncURLSessiobDownloadDelegate, tagsTaskIdenfier: any TaskIdentifiable) {
        self.cacheFolder = cacheFolder
        self.resourcesPool = resourcesPool
        self.defaultSession = defaultSession
        self.tagsTaskIdenfier = tagsTaskIdenfier
        self.defaultDownloadDelegate = defaultDownloadDelegate
    }
    
    static func create() -> Self {
        let folder = FileManager.default.temporaryDirectory
        let delegate = AsyncURLSessionDelegator(folder)
        let tags = TagsTaskIdentifier()
        let pool = ResoucesPool()
        let session = AsyncDownloadSession(delegate: delegate, tagsTaskIdenfier: tags)
        let config = AsyncURLSessionConfiguration(cacheFolder: folder,
                                                  resourcesPool: pool,
                                                  defaultSession: session,
                                                  defaultDownloadDelegate: delegate,
                                                  tagsTaskIdenfier: tags)
        Task {
            await AsyncSession(config).registerDefaultContext(session)
        }
        
        return config
    }
    
    /// 所有下载任务进度、完成、失败回调，异常的话就取.error事件，这个AsyncPassthroughSubject不会抛出错误
    public func allNews() -> AsyncPassthroughSubject<AsyncUpdateNews> {
        resourcesPool.subject
    }
    
    /// 生成新的内部session对象，此对象和defaultsession相似, 共用cacheFolder，如需要自定义session则需自行遵循AsyncCustomURLSession创建新的对象
    public func newsSession() -> any AsyncCustomURLSession {
        let folder = cacheFolder
        let delegate = AsyncURLSessionDelegator(folder)
        let tags = TagsTaskIdentifier()
        let session = AsyncDownloadSession(delegate: delegate, tagsTaskIdenfier: tags)
        return session
    }
}
