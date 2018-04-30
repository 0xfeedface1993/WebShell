//
//  PCDownloadTask.swift
//  WebShellExsample
//
//  Created by virus1993 on 2018/4/19.
//  Copyright © 2018年 ascp. All rights reserved.
//

import Foundation

public struct PCDownloadPack {
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
    /// 错误信息
    public var error : Error?
    
    init() {
        totalBytes = 0
        revBytes = 0
    }
}

public class PCDownloadTask: NSObject {
    public var request: PCDownloadRequest
    /// 文件名, 默认显示下载页面地址
    public var fileName: String
    /// 保存文件名，包含解压密码
    var saveFileName: String {
        let parts = fileName.split(separator: ".")
        let last = String(parts.last ?? "")
        let prefix = String(parts.dropLast().joined())
        return "\(prefix)(\(request.riffle?.password ?? "无密码")).\(last)"
    }
    /// 当下载目录存在相同的文件时使用时间前缀
    var timeStampFileName: String {
        let date = Date()
        let dateFormater = DateFormatter()
        dateFormater.dateFormat = "yyyy-MM-dd-HH:mm:SS-"
        return dateFormater.string(from: date) + saveFileName
    }
    /// http任务
    public var task: URLSessionDownloadTask
    /// 下载数据信息, 进度信息，当下载完成后包含已下载的数据信息
    public var pack = PCDownloadPack()
    /// 创建时间
    public let createTime = Date()
    
    init(request newRequest: PCDownloadRequest, task newTask: URLSessionDownloadTask) {
        self.request = newRequest
        self.task = newTask
        self.fileName = request.url.absoluteString
        super.init()
    }
}

public struct PCDownloadRequest {
    /// http报文头部键值对
    public var headFields : [String:String]
    /// 文件下载地址
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
    
    /// 该下载任务所属的网盘任务
    public weak var riffle: PCWebRiffle?
    /// 当任务非资源下载任务时，置为false
    public var isFileDownloadTask = true
    
    /// 下载进度更新回调
    var downloadStateUpdate : ((PCDownloadTask) -> ())?
    /// 下载完成回调
    var downloadFinished : ((PCDownloadTask) -> ())?
    
    init(headFields: [String:String], url : URL, method : HTTPMethod, body : Data?) {
        self.headFields = headFields
        self.url = url
        self.method = method
        self.body = body
    }
}
