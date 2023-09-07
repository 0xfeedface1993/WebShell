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

public struct AsyncURLSessionConfiguration {
    /// 文件临时存放目录，注意需要定时清除测量，或者使用系统tmp目录`FileManager.default.temporaryDirectory`
    var cacheFolder: URL
    /// session缓存，不同的站点使用不同的session防止互相影响，后续可以考虑使用cookies独立缓存替代
    var sessionPool: AsyncSessionPool
    /// 默认session缓存，不匹配的时候使用此缓存
    public var defaultSession: any AsyncCustomURLSession
    /// 运行时URLDownloadTask的taskIdentifier和任务tag缓存，下载模块的回调才能识别哪个任务对应哪个task，完成下载、进度更新、取消下载、错误才能通知外部
    var tagsTaskIdenfier: any TaskIdentifiable
    
    public static let shared = create()
    
    init(cacheFolder: URL, sessionPool: AsyncSessionPool, defaultSession: any AsyncCustomURLSession, tagsTaskIdenfier: any TaskIdentifiable) {
        self.cacheFolder = cacheFolder
        self.sessionPool = sessionPool
        self.defaultSession = defaultSession
        self.tagsTaskIdenfier = tagsTaskIdenfier
    }
    
    static func create() -> Self {
        let folder = FileManager.default.temporaryDirectory
        let delegate = AsyncURLSessionDelegator(folder)
        let tags = TagsTaskIdentifier()
        let pool = AsyncSessionPool()
        let session = AsyncDownloadSession(delegate: delegate, tagsTaskIdenfier: tags)
        let config = AsyncURLSessionConfiguration(cacheFolder: folder,
                                                  sessionPool: pool,
                                                  defaultSession: session,
                                                  tagsTaskIdenfier: tags)
        Task {
            await pool.set(session, for: .default)
        }
        
        return config
    }
}
