//
//  TBQueueItem.swift
//  WebShellExsample
//
//  Created by virus1994 on 2019/3/27.
//  Copyright © 2019 ascp. All rights reserved.
//

import Foundation

public protocol TBQueueItem {
    var tag : String { get set }
    var url : String { get }
    var site : WebHostSite { get }
    var downloadTask : URLSessionDownloadTask? { get set }
    var parserCreatTime: Date { get set }
    var startDownloadTime: Date? { get set }
    var endDownloadTime: Date? { get set }
    
    /// 下载进度，1.0为100%
    var progress : Float { get }
    /// 总共需要下载的字节数
    var totalBytes : Int64 { get set}
    /// 已经接收到的字节数
    var revBytes : Int64 { get set }
    /// 接受到的数据
    var revData : Data? { get set }
    var suggesetFileName : String? { get set }
}

public protocol TBPiplineRoomDelegate {
    func pipline(didFinishedSeat: TBQueueItem)
}

