//
//  DownloadManager.swift
//  CCCHOOO
//
//  Created by virus1993 on 2018/1/23.
//  Copyright © 2018年 ascp. All rights reserved.
//

import Foundation

class DownloadManager : NSObject {
    private static let _manager = DownloadManager()
    static var share : DownloadManager {
        get {
            return _manager
        }
    }
    private var session : URLSession!
    
    var tasks = [DownloadTask]()
    
    override init() {
        super.init()
//        let config = URLSessionConfiguration.background(withIdentifier: "download")
        let config = URLSessionConfiguration.default
//        config.isDiscretionary = true
        session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
    }
    
    func add(request: DownloadRequest) {
        let tk = session.downloadTask(with: request.request)
        let task = DownloadTask(request: request, task: tk)
        tasks.append(task)
        tk.resume()
        print("start task \(task.request.fileName)")
    }
}

extension DownloadManager : URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        var task = tasks.first(where: { $0.task == downloadTask })
        do {
            task?.revData = try Data(contentsOf: location)
            print("download \(task?.request.fileName ?? "") finish!")
            if let tk = task {
                task?.request.downloadFinished?(tk)
            }
        } catch {
            print("Download Save Error: \(error)")
        }
    }
    
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        print("didBecomeInvalidWithError: \(error != nil ? error!.localizedDescription : "no error")")
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        var task = tasks.first(where: { $0.task == downloadTask })
        task?.totalBytes = totalBytesExpectedToWrite
        task?.revBytes = totalBytesWritten
        if let tk = task {
            task?.request.downloadStateUpdate?(tk)
        }
    }
}
