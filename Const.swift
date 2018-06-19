//
//  Const.swift
//  WebShellExsample
//
//  Created by virus1993 on 2018/5/11.
//  Copyright © 2018年 ascp. All rights reserved.
//

#if os(macOS)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_3) AppleWebKit/604.5.6 (KHTML, like Gecko) Version/11.0.3 Safari/604.5.6"
let fullAccept = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
public let ImageFetchNotification = Notification.Name("com.ascp.image.code")
