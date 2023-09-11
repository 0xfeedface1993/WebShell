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

public protocol FileIDFinder {
    init(_ pattern: String)
    
    func extract(_ text: String) throws -> String
}

extension FileIDFinder where Self == FileIDMatch {
    public static var `default`: Self {
        FileIDMatch("\\-(\\w+)\\.\\w+$")
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
