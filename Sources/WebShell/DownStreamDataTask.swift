//
//  DownStreamDataTask.swift
//  WebShellExsample
//
//  Created by JohnConner on 2020/6/23.
//  Copyright © 2020 ascp. All rights reserved.
//

import Foundation

public class DownStreamDataTask {
    public typealias CancelToken = Int
    
    struct TaskCallback {
        let completed: ConfigDelegate<Result<Data, WebShellError>, Void>?
    }
    
    private var currentToken: Int = 0
    public private(set) var mutableData: Data
    
    public let task: URLSessionDataTask
    
    init(task: URLSessionDataTask) {
        self.task = task
        self.mutableData = Data()
    }
    
    private var callbackStore = [CancelToken: TaskCallback]()
    var callbacks: [TaskCallback] {
        lock.lock()
        defer {
            lock.unlock()
        }
        return Array(callbackStore.values)
    }
    private var lock = NSLock()
    
    let onTaskDone = ConfigDelegate<Result<(Data, URLResponse)?, WebShellError>, Void>()
    let onTaskUpdate = ConfigDelegate<Result<(Data, URLResponse)?, WebShellError>, Void>()
    let onCallbackCancelled = ConfigDelegate<(CancelToken, TaskCallback), Void>()
    
    var started = false
    var containsCallback : Bool {
        !callbacks.isEmpty
    }
    
    func addCallback(_ callback: TaskCallback) -> CancelToken {
        lock.lock()
        defer {
            lock.unlock()
        }
        callbackStore[currentToken] = callback
        defer {
            currentToken += 1
        }
        return currentToken
    }
    
    func removeCallback(_ token: CancelToken) -> TaskCallback? {
        lock.lock()
        defer {
            lock.unlock()
        }
        if let callback = callbackStore[token] {
            callbackStore[token] = nil
            return callback
        }
        return nil
    }
    
    func resume() {
        guard !started else {
            return
        }
        started = true
        task.resume()
    }
    
    func cancel(token: CancelToken) {
        guard let callback = removeCallback(token) else {
            return
        }
        if callbackStore.count == 0 {
            task.cancel()
        }
        onCallbackCancelled.call((token, callback))
    }
    
    func fourceCancel() {
        for token in callbackStore.keys {
            cancel(token: token)
        }
    }
    
    func didReceiveData(_ data: Data) {
        mutableData.append(data)
    }
}
