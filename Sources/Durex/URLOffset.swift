//
//  File.swift
//  
//
//  Created by john on 2023/6/21.
//

import Foundation

public struct URLOffset {
    public let rawURL: URL
    
    public init(rawURL: URL) {
        self.rawURL = rawURL
    }
    
    public func predictHost() -> String? {
        guard let host = host(), !host.isEmpty else {
            return try? matchHost(in: rawURL.absoluteString)
        }
        return host
    }
    
    private func host() -> String? {
        rawURL.unitiedHost()
    }
    
    private func matchHost(in string: String) throws -> String {
        if #available(macOS 13.0, *) {
            let regx = try Regex("(\\w+\\.)+\\w+")
            guard let match = string.firstMatch(of: regx)?.0 else {
#if DEBUG
                logger.error("[\(type(of: self))] no host in \(string)")
#endif
                throw DurexError.missingHost
            }
            
#if DEBUG
            logger.info("[\(type(of: self))] extract host \(match) from \(string)")
#endif
            
            return String(match)
        } else {
            // Fallback on earlier versions
            let regx = try NSRegularExpression(pattern: "(\\w+\\.)+\\w+")
            guard let range = regx.firstMatch(in: string, range: NSRange(location: 0, length: string.count))?.range else {
#if DEBUG
                logger.error("[\(type(of: self))] no host in \(string)")
#endif
                throw DurexError.missingHost
            }
#if DEBUG
            logger.info("[\(type(of: self))] extract host \((string as NSString).substring(with: range)) from \(string)")
#endif
            return (string as NSString).substring(with: range)
        }
    }
}

extension URL {
    func unitiedHost() -> String? {
#if os(macOS) && os(iOS) && os(watchOS)
        if #available(macOS 13.0, *) {
            return host(percentEncoded: false)
        } else {
            // Fallback on earlier versions
            return host
        }
#else
        return host
#endif
    }
}
