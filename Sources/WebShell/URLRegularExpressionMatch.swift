//
//  URLRegularExpressionMatch.swift
//  WebShell
//
//  Created by john on 2023/5/4.
//  Copyright © 2023 ascp. All rights reserved.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import Durex

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
    let string: String
    let pattern: String
    let template: URLRegularExpressionMatchTemplate
    
    func extract() throws -> [URL] {
        try ExpressionMatch(string: string, pattern: pattern, template: template)
            .extract()
            .compactMap(URL.init(string:))
    }
    
    init(string: String, pattern: String, template: URLRegularExpressionMatchTemplate) {
        self.string = string
        self.pattern = pattern
        self.template = template
    }
    
    init(_ string: String) {
        self.string = string
        self.pattern = "\\w"
        self.template = Templates.dollar(0)
    }
    
    func pattern(_ value: String) -> Self {
        .init(string: string, pattern: value, template: template)
    }
    
    func template(_ value: URLRegularExpressionMatchTemplate) -> Self {
        .init(string: string, pattern: pattern, template: value)
    }
}

public protocol ContentMatch {
    func extract(_ text: String) throws -> [URL]
}

public protocol DownloadRequestBuilder {
    func make(_ url: String, refer: String) -> URLRequestBuilder
}

enum ExpressionMatchError: Error {
    case noMatchedValue(pattern: String)
}

public struct ExpressionMatch {
    public let string: String
    public let pattern: String
    public let template: URLRegularExpressionMatchTemplate
    
    public  func extract() throws -> [String] {
        if #available(iOS 16.0, macOS 13.0, *) {
            let regx = try Regex(pattern)
            let urls = string.matches(of: regx).compactMap({ $0.output[template.rawTemplate()].substring })
            return urls.map({ String($0) })
        } else {
            // Fallback on earlier versions
            let regx = try NSRegularExpression(pattern: pattern)
            let nsString = string as NSString
            let range = NSRange(location: 0, length: nsString.length)
            return regx.matches(in: string, range: range)
                .map { result in
                    regx.replacementString(for: result, in: string, offset: 0, template: template.template())
                }
        }
    }
    
    func takeFirst() throws -> String {
        guard let first = try extract().first else {
            throw ExpressionMatchError.noMatchedValue(pattern: pattern)
        }
        return first
    }
    
    public init(string: String, pattern: String, template: URLRegularExpressionMatchTemplate) {
        self.string = string
        self.pattern = pattern
        self.template = template
    }
    
    public init(_ string: String) {
        self.string = string
        self.pattern = "\\w"
        self.template = Templates.dollar(0)
    }
    
    public func pattern(_ value: String) -> Self {
        .init(string: string, pattern: value, template: template)
    }
    
    public func template(_ value: URLRegularExpressionMatchTemplate) -> Self {
        .init(string: string, pattern: pattern, template: value)
    }
}
