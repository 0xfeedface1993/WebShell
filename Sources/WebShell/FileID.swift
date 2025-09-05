//
//  FileID.swift
//  WebShellExsample
//
//  Created by john on 2023/3/29.
//  Copyright © 2023 ascp. All rights reserved.
//

import Foundation

#if canImport(Durex)
import Durex
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol FileIDFinder: Sendable {
    init(_ pattern: String)
    
    func extract(_ text: String) throws -> String
}

public protocol BatchSearchFinder: FileIDFinder {
    func batch(_ text: String) throws -> [String]
}

extension FileIDFinder where Self == FileIDMatch {
    public static var `default`: Self {
        FileIDMatch("\\-(\\w+)\\.\\w+$")
    }
    
    public static var inQueryfileID: Self {
        FileIDMatch("=(\\d+)$")
    }
    
    public static var loadDownAddr1: Self {
        FileIDMatch("load_down_addr1\\('([\\w\\d]+)'\\)")
    }
    
    public static var downProcess4: Self {
        FileIDMatch("down_process4\\(\"([\\w\\d]+)\"\\)")
    }
    
    public static var lastPath: Self {
        FileIDMatch("/([\\w\\d]+)$")
    }
    
    public static var formhash: Self {
        FileIDMatch("name=\"formhash\"\\s+value=\"([^\"]+)\"")
    }
    
    public static var sign: Self {
        FileIDMatch("&sign=(\\w+)&")
    }
    
    public static var href: Self {
        FileIDMatch("href=\"([^\"]+)\"")
    }
    
    public static var httpHref: Self {
        FileIDMatch("href=\"(https?:[^\"]+)\"")
    }
    
    public static var addRef: Self {
        FileIDMatch("add_ref\\((\\d+)\\)")
    }
    
    public static var addCoun: Self {
        FileIDMatch("add_coun\\((\\d+)\\)")
    }
    
    public static var logined: Self {
        FileIDMatch(pattern: "(Login\\s+successful)|(登錄成功)|(登录成功)|(您已登录)|(欢迎回来)", template: .dollar(0))
    }
    
    public static var redirectLogined: Self {
        FileIDMatch(pattern: "Redirecting\\sto\\s<a\\shref=\"([^\"]+)\">", template: .dollar(1))
    }
    
    public static var paidUser: Self {
        FileIDMatch(pattern: "PAID\\sUSER", template: .dollar(0))
    }
    
    public static var windowHTTP: Self {
        FileIDMatch(pattern: "window\\.location\\s=\\s'([^']+)'", template: .dollar(1))
    }
    
    public static var userConfig: Self {
        FileIDMatch(pattern: "帐户设置", template: .dollar(0))
    }
    
    
    public static var invalidCode: Self {
        FileIDMatch(pattern: "验证码不正确", template: .dollar(0))
    }
    
    public static var invalidPassword: Self {
        FileIDMatch(pattern: "(密码不正确)|(密碼不正確)|(password is incorrect)", template: .dollar(0))
    }
    
    public static var invalidPassword2: Self {
        FileIDMatch(pattern: "Your username and password are invalid", template: .dollar(0))
    }
    
    public static var vipExpired: Self {
        FileIDMatch(pattern: "VIP已过期", template: .dollar(0))
    }
    
    public static var notVip: Self {
        FileIDMatch(pattern: "You are not yet a VIP", template: .dollar(0))
    }
    
    public static var redirectDashboardLogined: Self {
        FileIDMatch(pattern: "Redirecting to [^\\s]+dashboard", template: .dollar(0))
    }
    
    public static var csrfMetaToken: Self {
        FileIDMatch(pattern: "name=\"csrf\\-token\" content=\"([^\"]+)\"", template: .dollar(1))
    }
}

/// 从链接中提取fileid，`http://xxxx/file-123456.html`提取fileid`123456`
public struct FileIDMatch: FileIDFinder {
    let pattern: String
    let template: Templates
    
    public init(_ pattern: String) {
        self.init(pattern: pattern)
    }
    
    init(pattern: String = "\\-(\\w+)\\.\\w+$", template: Templates = .dollar(1)) {
        self.pattern = pattern
        self.template = template
    }
    
    func template(_ value: Templates) -> Self {
        .init(pattern: pattern, template: value)
    }
    
    public func extract(_ text: String) throws -> String {
        try ExpressionMatch(text)
            .pattern(pattern)
            .template(template)
            .takeFirst()
    }
}

extension FileIDMatch: BatchSearchFinder {
    public func batch(_ text: String) throws -> [String] {
        try ExpressionMatch(text)
            .pattern(pattern)
            .template(template)
            .extract()
    }
}
