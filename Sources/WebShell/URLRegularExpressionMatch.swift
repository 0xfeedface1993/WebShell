//
//  URLRegularExpressionMatch.swift
//  WebShell
//
//  Created by john on 2023/5/4.
//  Copyright © 2023 ascp. All rights reserved.
//

import Foundation

public protocol URLRegularExpressionMatchTemplate {
    func template() -> String
    func rawTemplate() -> Int
}

public enum Templates: URLRegularExpressionMatchTemplate {
    case dollar(UInt)
    
    public func template() -> String {
        switch self {
        case .dollar(let value):
            return "$\(value)"
        }
    }
    
    public func rawTemplate() -> Int {
        switch self {
        case .dollar(let value):
            return Int(value)
        }
    }
}

extension String: URLRegularExpressionMatchTemplate {
    public func rawTemplate() -> Int {
        Int(self) ?? 0
    }
    
    @inlinable
    public func template() -> String {
        self
    }
}

public struct URLRegularExpressionMatch {
    let url: String
    let pattern: String
    let template: URLRegularExpressionMatchTemplate
    
    func extract() throws -> [URL] {
        if #available(iOS 16.0, macOS 13.0, *) {
            let regx = try Regex(pattern)
            let urls = url.matches(of: regx).compactMap({ $0.output[template.rawTemplate()].substring })
            return urls.compactMap { value in
                URL(string: String(value))
            }
        } else {
            // Fallback on earlier versions
            let regx = try NSRegularExpression(pattern: pattern)
            let nsString = url as NSString
            let range = NSRange(location: 0, length: nsString.length)
            return regx.matches(in: url, range: range)
                .map { result in
                    regx.replacementString(for: result, in: url, offset: 0, template: template.template())
                }
                .compactMap(URL.init(string:))
        }
    }
}

public protocol ContentMatch {
    func extract(_ text: String) throws -> [URL]
}

public protocol DownloadRequestBuilder {
    func make(_ url: String, refer: String) throws -> URLRequest
}
