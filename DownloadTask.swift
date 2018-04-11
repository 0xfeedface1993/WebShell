//
//  DownloadTask.swift
//  CCCHOOO
//
//  Created by virus1993 on 2018/1/23.
//  Copyright © 2018年 ascp. All rights reserved.
//

import Foundation

/// 下载任务
public class DownloadTask : NSObject {
    /// 请求配置
    public var request : DownloadRequest
    /// http任务
    public var task : URLSessionDownloadTask
    /// 下载进度，1.0为100%
    public var progress : Float {
        return totalBytes > 0 ? Float(revBytes) / Float(totalBytes) : 0
    }
    /// 总共需要下载的字节数
    public var totalBytes : Int64
    /// 已经接收到的字节数
    public var revBytes : Int64
    /// 接受到的数据
    public var revData : Data?
    /// 创建时间
    public let createTime = Date()
    
    init(request newRequest: DownloadRequest, task newTask: URLSessionDownloadTask) {
        self.request = newRequest
        self.task = newTask
        self.totalBytes = 0
        self.revBytes = 0
        self.revData = nil
        super.init()
    }
}

/// 请求配置
public struct DownloadRequest {
    /// 唯一标签
    public var label : String
    /// 文件名
    public var fileName : String
    /// 下载进度更新回调
    var downloadStateUpdate : ((DownloadTask) -> ())?
    /// 下载完成回调
    var downloadFinished : ((DownloadTask) -> ())?
    /// http报文头部键值对
    public var headFields : [String:String]
    /// 地址
    public var url : URL
    /// http报文方法
    public var method : HTTPMethod
    /// httpBody，post的时候放参数
    public var body : Data?
    /// 用于URLSession, 启动下载任务
    public var request : URLRequest {
        get {
            var req = URLRequest(url: url)
            req.httpShouldHandleCookies = true
            req.httpMethod = method.rawValue
            req.timeoutInterval = 5 * 60
            for item in headFields {
                req.addValue(item.value, forHTTPHeaderField: item.key)
            }
            req.httpBody = body
            return req
        }
    }
}
