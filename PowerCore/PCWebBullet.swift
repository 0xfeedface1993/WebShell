//
//  PCWebBullet.swift
//  WebShellExsample
//
//  Created by virus1993 on 2018/4/20.
//  Copyright © 2018年 ascp. All rights reserved.
//

import Foundation

struct PCWebBullet {
    /// URLRequest对象，属于计算变量，根据其他变量生成
    var request : URLRequest {
        get {
            var req = URLRequest(url: url)
            req.httpMethod = method.rawValue
            for item in headFields {
                req.addValue(item.value, forHTTPHeaderField: item.key)
            }
            var body = ""
            for (index, item) in formData.enumerated() {
                body += "\(item.key)=\(item.value)\(index < formData.count - 1 ? "&":"")"
            }
            if body != "" {
                req.httpBody = body.data(using: .utf8)
            }
            return req
        }
    }
    /// http方法
    var method : HTTPMethod
    /// http请求头部自定义信息
    var headFields : [String:String]
    /// http报文body数据（x-www-form-urlencoded格式）
    var formData : [String:String]
    /// 访问url
    var url : URL
    /// 注入js，执行时间为当前页面载入完成后
    var injectJavaScript = [InjectUnit]()
    /// 已执行的js
    var finishedJavaScript = [InjectUnit]()
    
    init(method: HTTPMethod, headFields: [String:String], formData: [String:String], url: URL, injectJavaScript: [InjectUnit]) {
        self.method = method
        self.headFields = headFields
        self.formData = formData
        self.url = url
        self.injectJavaScript += injectJavaScript
    }
}

/// js注入模块
struct InjectUnit {
    /// 注入js
    var script : String
    /// js执行成功回调
    var successAction : ((Any?)->())?
    /// js执行失败回调
    var failedAction : ((Error)->())?
    var isAutomaticallyPass : Bool
}

public enum HTTPMethod : String {
    case post = "POST"
    case get = "GET"
}


