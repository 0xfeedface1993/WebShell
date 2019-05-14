//
//  TBDownloader.swift
//  WebShell_macOS
//
//  Created by virus1994 on 2019/5/10.
//  Copyright © 2019 ascp. All rights reserved.
//

import Cocoa

protocol TBDownloaderDelegate: class {
    func downloader(_ downloader: TBDownloader, updateTask: TBDownloader.TBDownloadInfo)
    func downloader(_ downloader: TBDownloader, finishTask: TBDownloader.TBDownloadInfo)
    func downloader(_ downloader: TBDownloader, interalError: Error?)
}

public class TBDownloader: NSObject {
    struct TBDownloadInfo {
        var task: URLSessionTask
        var totalBytes: Int64?
        var reciveBytes: Int64?
        var alreadyReciveBytes: Int64?
        var error: Error?
    }

    public static let share = TBDownloader()
    private var session : URLSession!
    weak var delegate : TBDownloaderDelegate?
    
    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
    }
}

extension TBDownloader: URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession,
                           downloadTask: URLSessionDownloadTask,
                           didWriteData bytesWritten: Int64,
                           totalBytesWritten: Int64,
                           totalBytesExpectedToWrite: Int64) {
        let task = TBDownloadInfo(task: downloadTask,
                                  totalBytes: totalBytesExpectedToWrite,
                                  reciveBytes: bytesWritten,
                                  alreadyReciveBytes: totalBytesWritten,
                                  error: nil)
        delegate?.downloader(self, updateTask: task)
    }
    
    public func urlSession(_ session: URLSession,
                           downloadTask: URLSessionDownloadTask,
                           didFinishDownloadingTo location: URL) {
        let task = TBDownloadInfo(task: downloadTask,
                                  totalBytes: nil,
                                  reciveBytes: nil,
                                  alreadyReciveBytes: nil,
                                  error: nil)
        delegate?.downloader(self, finishTask: task)
    }
    
    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           willPerformHTTPRedirection response: HTTPURLResponse,
                           newRequest request: URLRequest,
                           completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
    
    public func urlSession(_ session: URLSession,
                           didBecomeInvalidWithError error: Error?) {
        delegate?.downloader(self, interalError: error)
    }
    
    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           didCompleteWithError error: Error?) {
        let task = TBDownloadInfo(task: task,
                                  totalBytes: nil,
                                  reciveBytes: nil,
                                  alreadyReciveBytes: nil,
                                  error: error)
        delegate?.downloader(self, finishTask: task)
    }
}
