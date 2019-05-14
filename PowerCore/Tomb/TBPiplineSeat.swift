//
//  File.swift
//  WebShell_macOS
//
//  Created by virus1994 on 2019/5/6.
//  Copyright © 2019 ascp. All rights reserved.
//

import Cocoa
import WebKit

class TBPiplineSeat: TBQueueItem, Hashable {
    /// 任务创建请求
    struct TBRequest {
        /// 网盘页面地址
        var pageURL : URL
        /// 任务名称，用于文件保存和下载列表区分
        var taskName : String
        /// 后缀名，只有文件下载开始才会存在
        var extensionName : String?
        /// 解压密码，大部分压缩文件是有密码的
        var password : String?
        /// 站点类型
        var site : WebHostSite {
            return siteType(url: pageURL)
        }
        
        /// 保存文件名，包含解压密码
        var saveFileName: String {
            if let e = extensionName {
                return "\(taskName)(\(password ?? "")).\(e)"
            }
            return "\(taskName)(\(password ?? ""))"
        }
    }
    
    static func == (lhs: TBPiplineSeat, rhs: TBPiplineSeat) -> Bool {
        return lhs.tag == rhs.tag
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(tag)
        hasher.combine(originRequest.pageURL)
    }
    
    var tag: String = UUID().uuidString
    var site: WebHostSite {
        return originRequest.site
    }
    var url: String {
        return originRequest.pageURL.absoluteString
    }
    var originRequest: TBRequest
    var webview: WKWebView?
    weak var pipline: TBPipline?
    
    var downloadTask: URLSessionDownloadTask?
    var parserCreatTime: Date = Date()
    var startDownloadTime: Date?
    var endDownloadTime: Date?
    
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
    
    var suggesetFileName : String? {
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
    
    init(request: TBRequest) {
        self.originRequest = request
        let config = WKWebViewConfiguration()
        webview = WKWebView(frame: CGRect.zero, configuration: config)
        webview?.customUserAgent = userAgent
    }
    
    deinit {
        webview?.stopLoading()
        webview = nil
    }
}
