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
}

/// 从链接中提取fileid，`http://xxxx/file-123456.html`提取fileid`123456`
public struct FileIDMatch: FileIDFinder {
    var pattern = "\\-(\\w+)\\.\\w+$"
    
    public init(_ pattern: String) {
        self.pattern = pattern
    }
    
    public func extract(_ text: String) throws -> String {
        if #available(iOS 16.0, macOS 13.0, *) {
            let regx = try Regex(pattern)
            guard let match = text.firstMatch(of: regx),
                    let fileid = match.output[1].substring else {
                throw ShellError.regulaNotMatch(text)
            }
            return String(fileid)
        } else {
            // Fallback on earlier versions
            let regx = try NSRegularExpression(pattern: pattern)
            let nsString = text as NSString
            guard let result = regx.firstMatch(in: text, range: .init(location: 0, length: nsString.length)) else {
                throw ShellError.regulaNotMatch(text)
            }
            return regx.replacementString(for: result, in: text, offset: 0, template: "$1")
        }
    }
}
