//
//  TBPipline.swift
//  WebShellExsample
//
//  Created by virus1994 on 2019/3/27.
//  Copyright © 2019 ascp. All rights reserved.
//

import Foundation
import Combine

public class TBPipline {
    public enum PiplineError: Error {
        /// 等待队列和执行队列里面出现重复任务
        case reduplicateTask
        case unkownsite
    }
    public static let share = TBPipline()
    /// 执行队列，当前正在执行的解析或下载任务
    public var currentQueue = [TBPiplineSeat]()
    /// 等待队列，等待执行的任务，FIFO队列
    public var waitQueue = [TBPiplineSeat]()
    
    init() { }
    
    /// 添加解析任务
    ///
    /// - Parameter task: 解析任务参数结构体
    /// - Returns: 成功则返回 TBPiplineSeat 对象，否则返回 Error
    public func add(task: TBPiplineSeat) -> Result<TBPiplineSeat, PiplineError> {
        let seat = task
        
        guard seat.site != .unknowsite else {
            return .failure(.unkownsite)
        }
        
        if let _ = currentQueue.first(where: { $0.site == seat.site }) {
            if let _ = waitQueue.first(where: { $0.url == seat.url }) {
                return .failure(.reduplicateTask)
            }
            waitQueue.append(seat)
            return .failure(.reduplicateTask)
        }
        
        currentQueue.append(seat)
        return .success(seat)
    }
    
    /// 查找站点下一个任务并执行
    ///
    /// - Parameter site: 站点
    public func next(taskInSite site: WebHostSite) {
        if let _ = currentQueue.first(where: { $0.site == site }) {
            log(message: "Already have \(site) in progress, wait!")
            return
        }
        
        if let wait = waitQueue.firstIndex(where: { $0.site == site }) {
            log(message: "Move wait task \(waitQueue[wait].tag) to working queue!")
            currentQueue.append(waitQueue[wait])
            waitQueue.remove(at: wait)
            
            // 执行解析任务
            // 下一步解析工作
            return
        }
        
        log(message: "No task in any queue. sleep for new task arrived.")
    }
    
    /// 完成当前站点下正在执行的任务，该任务下载完成、失败都会调用
    ///
    /// - Parameter site: 站点
    public func finish(taskInSite site: WebHostSite) {
        defer {
            next(taskInSite: site)
        }
        
        guard let current = currentQueue.firstIndex(where: { $0.site == site }) else {
            log(message: "No \(site) task in current queue.")
            return
        }
        
        // 保存已完成任务状态
        currentQueue.remove(at: current)
    }
}

extension TBPipline: Logger {
    public func pipline(didFinishedSeat: TBPiplineSeat) {
        finish(taskInSite: didFinishedSeat.site)
    }
}

extension TBPipline : TBDownloaderDelegate {
    func downloader(_ downloader: TBDownloader, updateTask: TBDownloader.TBDownloadInfo) {
        guard let downloadTask = updateTask.task as? URLSessionDownloadTask else {
            log(error: "Downloader task not in working queue. \(updateTask.task)")
            return
        }
        
        guard let index = currentQueue.firstIndex(where: { $0.downloadTask == downloadTask }) else {
            log(error: "Downloader task not match any task in working queue. \(updateTask.task)")
            return
        }
        
        if let e = updateTask.error {
            log(error: "Download error: \(e.localizedDescription). \(updateTask.task)")
            currentQueue[index].endDownloadTime = Date()
            finish(taskInSite: currentQueue[index].site)
            let seat = currentQueue[index]
            seat.downloadCompletion(.failure(e))
            return
        }
        
        currentQueue[index].revBytes = updateTask.reciveBytes ?? 0
        currentQueue[index].totalBytes = updateTask.totalBytes ?? 0
        currentQueue[index].suggesetFileName = downloadTask.response?.suggestedFilename
        // 更新操作
        // currentQueue[index].progressCompletion(currentQueue[index])
    }
    
    func downloader(_ downloader: TBDownloader, finishTask: TBDownloader.TBDownloadInfo) {
        guard let downloadTask = finishTask.task as? URLSessionDownloadTask else {
            log(error: "Finished task not in working queue. \(finishTask.task)")
            return
        }
        
        guard let index = self.currentQueue.firstIndex(where: { $0.downloadTask == downloadTask }) else {
            log(error: "Finished task not match any task in working queue. \(finishTask.task)")
            return
        }
        
        self.currentQueue[index].endDownloadTime = Date()
        
        if let e = finishTask.error {
            log(error: "Download finished error: \(e.localizedDescription). \(finishTask.task)")
            return
        }
        
        // 文件下载完成操作
        // currentQueue[index].downloadCompletion(.success(currentQueue[index]))
    }
    
    func downloader(_ downloader: TBDownloader, interalError: Error?) {
        log(error: "Downloader failed due to interalError: \(interalError?.localizedDescription ?? "Unknown Error").")
//        let date = Date()
//
//        for index in 0..<currentQueue.count {
//            currentQueue[index].endDownloadTime = date
//        }
//
//        for index in 0..<waitQueue.count {
//            waitQueue[index].endDownloadTime = date
//        }
//
//        let all = currentQueue + waitQueue
//        all.forEach({
//            if let e = interalError {
//                $0.downloadCompletion(.failure(e))
//            }
//        })
//        currentQueue.removeAll()
//        waitQueue.removeAll()
    }
}

protocol Logger {
    
}

extension Logger {
    func log(message: String) {
        print(">>>>>> \(message)")
    }
    
    func log(error: String) {
        print("****** \(error)")
    }
}
