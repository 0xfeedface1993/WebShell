//
//  DownloadTask.swift
//  CCCHOOO
//
//  Created by virus1993 on 2018/1/23.
//  Copyright © 2018年 ascp. All rights reserved.
//

import Foundation

struct DownloadTask {
    var request : DownloadRequest
    var task : URLSessionDownloadTask
    var progress : Float {
        return totalBytes > 0 ? Float(revBytes) / Float(totalBytes) : 0
    }
    var totalBytes : Int64
    var revBytes : Int64
    var revData : Data?
    
    init(request newRequest: DownloadRequest, task newTask: URLSessionDownloadTask) {
        self.request = newRequest
        self.task = newTask
        self.totalBytes = 0
        self.revBytes = 0
        self.revData = nil
    }
}

struct DownloadRequest {
    var label : String
    var fileName : String
    var downloadStateUpdate : ((DownloadTask) -> ())?
    var downloadFinished : ((DownloadTask) -> ())?
    var headFields : [String:String]
    var url : URL
    var request : URLRequest {
        get {
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            for item in headFields {
                req.addValue(item.value, forHTTPHeaderField: item.key)
            }
            return req
        }
    }
}
