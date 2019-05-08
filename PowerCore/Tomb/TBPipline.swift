//
//  TBPipline.swift
//  WebShellExsample
//
//  Created by virus1994 on 2019/3/27.
//  Copyright © 2019 ascp. All rights reserved.
//

import Foundation

class TBPipline {
    static let share = TBPipline()
    var currentItem : TBQueueItem?
    var waitQueue = [TBQueueItem]()
    var seats = [TBQueueItem]()
    
    init() {
        
    }
}
