//
//  DownloadTask.swift
//  CCCHOOO
//
//  Created by virus1993 on 2018/1/23.
//  Copyright © 2018年 ascp. All rights reserved.
//

import Foundation

/// 下载任务
struct DownloadTask {
    /// 请求配置
    var request : DownloadRequest
    /// http任务
    var task : URLSessionDownloadTask
    /// 下载进度，1.0为100%
    var progress : Float {
        return totalBytes > 0 ? Float(revBytes) / Float(totalBytes) : 0
    }
    /// 总共需要下载的字节数
    var totalBytes : Int64
    /// 已经接收到的字节数
    var revBytes : Int64
    /// 接受到的数据
    var revData : Data?
    
    init(request newRequest: DownloadRequest, task newTask: URLSessionDownloadTask) {
        self.request = newRequest
        self.task = newTask
        self.totalBytes = 0
        self.revBytes = 0
        self.revData = nil
    }
}

/// 请求配置
struct DownloadRequest {
    /// 唯一标签
    var label : String
    /// 文件名
    var fileName : String
    /// 下载进度更新回调
    var downloadStateUpdate : ((DownloadTask) -> ())?
    /// 下载完成回调
    var downloadFinished : ((DownloadTask) -> ())?
    /// http报文头部键值对
    var headFields : [String:String]
    /// 地址
    var url : URL
    /// http报文方法
    var method : HTTPMethod
    /// httpBody，post的时候放参数
    var body : Data?
    /// 用于URLSession, 启动下载任务
    var request : URLRequest {
        get {
            var req = URLRequest(url: url)
            req.httpShouldHandleCookies = true
            req.httpMethod = method.rawValue
            for item in headFields {
                req.addValue(item.value, forHTTPHeaderField: item.key)
            }
            req.httpBody = body
            return req
        }
    }
}
