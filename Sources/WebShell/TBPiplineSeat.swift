//
//  File.swift
//  WebShell_macOS
//
//  Created by virus1994 on 2019/5/6.
//  Copyright © 2019 ascp. All rights reserved.
//

#if os(macOS)
import Cocoa
#elseif os(iOS)
import UIKit
#endif
import WebKit

final public class TBPiplineSeat: TBQueueItem, Hashable {
    /// 任务创建请求
    public struct TBRequest {
        /// 网盘页面地址
        public var pageURL : URL
        /// 任务名称，用于文件保存和下载列表区分
        public var taskName : String
        /// 后缀名，只有文件下载开始才会存在
        public var extensionName : String?
        /// 解压密码，大部分压缩文件是有密码的
        public var password : String?
        /// 站点类型
        public var site : WebHostSite {
            return siteType(url: pageURL)
        }
        
        /// 保存文件名，包含解压密码
        public var saveFileName: String {
            if let e = extensionName {
                return "\(taskName)(\(password ?? "")).\(e)"
            }
            return "\(taskName)(\(password ?? ""))"
        }
    }
    
    public static func == (lhs: TBPiplineSeat, rhs: TBPiplineSeat) -> Bool {
        return lhs.tag == rhs.tag
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(tag)
        hasher.combine(originRequest.pageURL)
    }
    
    public var tag: String = UUID().uuidString
    public var site: WebHostSite {
        return originRequest.site
    }
    public var url: String {
        return originRequest.pageURL.absoluteString
    }
    var originRequest: TBRequest
    weak var pipline: TBPipline?
    
    public var downloadTask: URLSessionDownloadTask?
    public var parserCreatTime: Date = Date()
    public var startDownloadTime: Date?
    public var endDownloadTime: Date?
    
    /// 下载完成/失败回调
    public var downloadCompletion: (Result<TBPiplineSeat, Error>) -> Void
    /// 下载进度变化回调
    public var progressCompletion: (TBPiplineSeat) -> Void
    
    /// 下载进度，1.0为100%
    public var progress : Float {
        return totalBytes > 0 ? Float(revBytes) / Float(totalBytes) : 0
    }
    /// 总共需要下载的字节数
    public var totalBytes : Int64 = 0
    /// 已经接收到的字节数
    public var revBytes : Int64 = 0
    /// 接受到的数据
    public var revData : Data?
    
    public var suggesetFileName : String? {
        set {
            if originRequest.extensionName == nil,
                let name = newValue?.components(separatedBy: ".").last {
                originRequest.extensionName = name
            }
        }
        
        get {
            return originRequest.extensionName
        }
    }
    
    init(request: TBRequest, downloadCompletion: @escaping (Result<TBPiplineSeat, Error>) -> Void, progressCompletion: @escaping (TBPiplineSeat) -> Void) {
        self.originRequest = request
        self.downloadCompletion = downloadCompletion
        self.progressCompletion = progressCompletion
    }
    
    public func parserEnd() {
        
    }
    
    public func load(task: URLSessionDownloadTask) {
        self.downloadTask = task
    }
}
