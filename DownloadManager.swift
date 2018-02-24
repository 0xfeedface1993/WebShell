//
//  DownloadManager.swift
//  CCCHOOO
//
//  Created by virus1993 on 2018/1/23.
//  Copyright © 2018年 ascp. All rights reserved.
//

import Foundation

/// 下载状态数据模型，用于视图数据绑定
class DownloadInfo : NSObject {
    var uuid = ""
    @objc dynamic var name = ""
    @objc dynamic var progress = ""
    @objc dynamic var totalBytes = ""
    @objc dynamic var site = ""
    @objc dynamic var state = ""
    override init() {
        super.init()
    }
}

/// 下载管理器，单例实现
class DownloadManager : NSObject {
    private static let _manager = DownloadManager()
    /// 外部访问的单例对象
    static var share : DownloadManager {
        get {
            return _manager
        }
    }
    private var session : URLSession!
    
    var tasks = [DownloadTask]()
    
    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
    }
    
    
    /// 添加下载任务，并开始执行下载
    ///
    /// - Parameter request: 下载任务
    func add(request: DownloadRequest) {
        let tk = session.downloadTask(with: request.request)
        let task = DownloadTask(request: request, task: tk)
        tasks.append(task)
        tk.resume()
        print("start task \(task.request.fileName)")
    }
}

extension DownloadManager : URLSessionDownloadDelegate {
    /// 下载完成代理方法
    ///
    /// - Parameters:
    ///   - session: 会话对象
    ///   - downloadTask: http下载任务对象
    ///   - location: 临时下载文件本地地址
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        var task = tasks.first(where: { $0.task == downloadTask })
        do {
            task?.revData = try Data(contentsOf: location)
            print("download \(task?.request.fileName ?? "") finish!")
            if let tk = task {
                // 调用下载完成回调
                task?.request.downloadFinished?(tk)
            }
        } catch {
            print("Download Save Error: \(error)")
        }
    }
    
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        print("didBecomeInvalidWithError: \(error != nil ? error!.localizedDescription : "no error")")
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print("didCompleteWithError: \(error.debugDescription)")
    }
    
    /// 下载进度更新代理方法
    ///
    /// - Parameters:
    ///   - session: 会话
    ///   - downloadTask: http下载任务
    ///   - bytesWritten: 本次下载多少字节
    ///   - totalBytesWritten: 已经下载多少字节
    ///   - totalBytesExpectedToWrite: 一共需要下载多少字节
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        var task = tasks.first(where: { $0.task == downloadTask })
        task?.totalBytes = totalBytesExpectedToWrite
        task?.revBytes = totalBytesWritten
        if let tk = task {
            print("------ name: \(tk.request.fileName) ------ progress: \(tk.progress) ------")
            // 调用下载更新回调
            task?.request.downloadStateUpdate?(tk)
        }
    }
}
