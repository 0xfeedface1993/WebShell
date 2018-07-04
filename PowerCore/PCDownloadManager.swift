//
//  PCDownloadManager.swift
//  WebShellExsample
//
//  Created by virus1993 on 2018/4/19.
//  Copyright © 2018年 ascp. All rights reserved.
//

import Foundation

public class PCDownloadManager: NSObject {
    private static let _manager = PCDownloadManager()
    private let pipline = PCPipeline.share
    /// 外部访问的单例对象
    public static var share : PCDownloadManager {
        get {
            return _manager
        }
    }
    
    private var session : URLSession!
    
    var tasks = [PCDownloadTask]()
    
    public var allTasks: [PCDownloadTask] {
        return tasks
    }
    
    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
    }
    
    /// 查找下载任务在序列中的位置
    ///
    /// - Parameter task: HTTP下载任务
    /// - Returns: 若找不到则返回nil
    func findTask(withDownloadTask task: URLSessionDownloadTask) -> Int? {
        return tasks.index(where: { $0.task == task })
    }
    
    /// 添加下载任务，并开始执行下载
    ///
    /// - Parameter request: 下载任务
    func add(request: PCDownloadRequest) {
        let tk = session.downloadTask(with: request.request)
        let task = PCDownloadTask(request: request, task: tk)
        tasks.append(task)
        tk.resume()
        print(">>>>>>>> start task \(task.fileName)")
    }
    
    func remove(fromRiffle riffle: PCWebRiffle) {
        if let index = tasks.index(where: { $0.request.riffle == riffle }) {
            tasks[index].task.cancel()
            tasks.remove(at: index)
        }
    }
}

extension PCDownloadManager : URLSessionDownloadDelegate {
    /// 下载完成代理方法
    ///
    /// - Parameters:
    ///   - session: 会话对象
    ///   - downloadTask: http下载任务对象
    ///   - location: 临时下载文件本地地址
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let index = findTask(withDownloadTask: downloadTask) else {
            print("*********** task not in manager sequence: \(downloadTask.response?.url?.absoluteString ?? "no url")")
            return
        }
        
        do {
            tasks[index].pack.revData = try Data(contentsOf: location)
            print("download \(tasks[index].fileName) finish!")
            // 调用下载完成回调
            let task = tasks[index]
            tasks[index].request.downloadFinished?(tasks[index])
            pipline.delegate?.pipline?(didFinishedTask: task)
            tasks[index].pack.revData = nil
            guard tasks[index].request.isFileDownloadTask else {
                print("*********** None File Download Task! No Delegate Excute")
                print("*********** Remove Download task: \(tasks[index].request)")
                PCDownloadManager.share.tasks.remove(at: index)
                return
            }
        } catch {
            print("Download Save Error: \(error)")
            // 调用下载完成回调
            tasks[index].pack.error = error
            tasks[index].request.downloadFinished?(tasks[index])
            guard tasks[index].request.isFileDownloadTask else {
                print("*********** None File Download Task! No Delegate Excute")
                if let riffle = tasks[index].request.riffle {
                    pipline.delegate?.pipline?(didFinishedRiffle: riffle)
                }
                return
            }
        }
    }
    
    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        guard let e = error else { return }
        print("*********** didBecomeInvalidWithError: \(e.localizedDescription)")
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let e = error else { return }
        guard let tk = task as? URLSessionDownloadTask, let index = findTask(withDownloadTask: tk) else {
            print("*********** task not in manager sequence: \(task.response?.url?.absoluteString ?? "no url")")
            return
        }
        
        print("*********** download \(tasks[index].fileName) with error finished: \(e)")
        
        tasks[index].pack.error = error
        let task = tasks[index]
        tasks[index].request.downloadFinished?(tasks[index])
        // 当下载任务非文件下载任务时，不执行通知
        if task.request.isFileDownloadTask {
            pipline.delegate?.pipline?(didFinishedTask: task)
        }   else    {
            print("*********** None File Download Task!")
            if let riffle = task.request.riffle {
                pipline.delegate?.pipline?(didFinishedRiffle: riffle)
            }
        }
        
        tasks[index].pack.revData = nil
    }
    
    /// 下载进度更新代理方法
    ///
    /// - Parameters:
    ///   - session: 会话
    ///   - downloadTask: http下载任务
    ///   - bytesWritten: 本次下载多少字节
    ///   - totalBytesWritten: 已经下载多少字节
    ///   - totalBytesExpectedToWrite: 一共需要下载多少字节
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let index = findTask(withDownloadTask: downloadTask) else {
            print("*********** task not in manager sequence: \(downloadTask.response?.url?.absoluteString ?? "no url")")
            return
        }
        
        if let name = downloadTask.response?.suggestedFilename {
            tasks[index].fileName = name
        }
        
        tasks[index].pack.totalBytes = totalBytesExpectedToWrite
        tasks[index].pack.revBytes = totalBytesWritten
        print("------ name: \(tasks[index].fileName) ------ progress: \(tasks[index].pack.progress) ------")
        
        tasks[index].request.downloadStateUpdate?(tasks[index])
        
        // 当下载任务非文件下载任务时，不执行通知
        guard tasks[index].request.isFileDownloadTask else {
            print("*********** None File Download Task! No Delegate Excute")
            return
        }
        
        // delegate
        pipline.delegate?.pipline?(didUpdateTask: tasks[index])
    }
    
    // 拦截自动重定向
    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
