//
//  WebBullet.swift
//  CCCHOOO
//
//  Created by virus1993 on 2018/1/23.
//  Copyright © 2018年 ascp. All rights reserved.
//

import Foundation

struct WebBullet {
    var request : URLRequest {
        get {
            var req = URLRequest(url: url)
            req.httpMethod = method.rawValue
            for item in headFields {
                req.addValue(item.value, forHTTPHeaderField: item.key)
            }
            var body = ""
            for item in formData {
                body += "\(item.key)=\(item.value)&"
            }
            if body != "" {
                req.httpBody = body.data(using: .utf8)
            }
            return req
        }
    }
    var successAction : ((Any?)->())?
    var failedAction : ((Error)->())?
    var method : HTTPMethod
    var headFields : [String:String]
    var formData : [String:String]
    var url : URL
    var injectJavaScript : String
}

enum HTTPMethod : String {
    case post = "POST"
    case get = "GET"
}


