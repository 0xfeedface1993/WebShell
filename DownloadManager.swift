//
//  DownloadManager.swift
//  CCCHOOO
//
//  Created by virus1993 on 2018/1/23.
//  Copyright © 2018年 ascp. All rights reserved.
//

import Foundation

/// 下载状态数据模型，用于视图数据绑定
public class DownloadInfo : NSObject {
    public var uuid = ""
    public var createTime = Date(timeIntervalSince1970: 0)
    @objc public dynamic var name = ""
    @objc public dynamic var progress = ""
    @objc public dynamic var totalBytes = ""
    @objc public dynamic var site = ""
    @objc public dynamic var state = ""
    override init() {
        super.init()
    }
    
    init(task: DownloadTask) {
        super.init()
        uuid = task.request.label
        name = task.request.fileName
        progress = "\(task.progress * 100)%"
        totalBytes = "\(Float(task.totalBytes) / 1024.0 / 1024.0)M"
        site = task.request.url.host!
        createTime = task.createTime
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
        guard let task = tasks.first(where: { $0.task == downloadTask }) else { return }
        let pipline = Pipeline.share
        do {
            task.revData = try Data(contentsOf: location)
            print("download \(task.request.fileName) finish!")
            // 调用下载完成回调
            task.request.downloadFinished?(task)
            guard task.request.isDelegateEnable else {
                print("None File Download Task! No Delegate Excute")
                return
            }
            pipline.delegate?.pipline?(didFinishedTask: task, withError: nil)
        } catch {
            print("Download Save Error: \(error)")
            guard task.request.isDelegateEnable else {
                print("None File Download Task! No Delegate Excute")
                return
            }
            pipline.delegate?.pipline?(didFinishedTask: task, withError: nil)
        }
    }
    
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        print("didBecomeInvalidWithError: \(error != nil ? error!.localizedDescription : "no error")")
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let e = error else { return }
        print("didCompleteWithError: \(e)")
        guard let tk = tasks.first(where: { $0.task == task }) else { return }
        print("download \(tk.request.fileName) with error finished!")
        tk.request.downloadFinished?(tk)
        guard tk.request.isDelegateEnable else {
            print("None File Download Task! No Delegate Excute")
            return
        }
        let pipline = Pipeline.share
        pipline.delegate?.pipline?(didFinishedTask: tk, withError: error)
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
        if let index = tasks.index(where: { $0.task == downloadTask }) {
            tasks[index].totalBytes = totalBytesExpectedToWrite
            tasks[index].revBytes = totalBytesWritten
            print("------ name: \(tasks[index].request.fileName) ------ progress: \(tasks[index].progress) ------")
            // 调用下载更新回调
            tasks[index].request.downloadStateUpdate?(tasks[index])
            guard tasks[index].request.isDelegateEnable else {
                print("None File Download Task! No Delegate Excute")
                return
            }
            let pipline = Pipeline.share
            pipline.delegate?.pipline?(didUpdateTask: tasks[index])
        }
    }
}
