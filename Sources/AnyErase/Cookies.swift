//
//  File.swift
//  
//
//  Created by john on 2023/8/20.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct CookiesReader {
    public let session: URLSession
    
    public init(_ session: URLSession) {
        self.session = session
    }
    
    /// 原始的cookie对象
    public func rawCookies() -> [HTTPCookie] {
        guard let storage = session.configuration.httpCookieStorage else {
            logger.warning("no httpCookieStorage!")
            return []
        }
        
        guard let cookies = storage.cookies else {
            logger.warning("no httpCookieStorage.cookies!")
            return []
        }
        
        logger.info("has \(cookies.count) cookies.")
        return cookies
    }
    
    /// 生成请求头的header键值对
    public func requestHeaderFields() -> [String: String] {
        HTTPCookie.requestHeaderFields(with: rawCookies())
    }
    
    /// 所有的cookies转化为键值对
    public func allCookies() -> [String: String] {
        let allFields = requestHeaderFields()
        logger.info("requestHeaderFields: \(allFields)")
        return allFields["Cookie"]?
            .replacingOccurrences(of: " ", with: "")
            .components(separatedBy: ";")
            .compactMap(split(_:))
            .reduce(into: [:], { $0[$1.0] = $1.1 }) ?? [:]
    }
    
    public func sortCookiesDescription() -> String {
        let text = allCookies()
            .sorted { $0.key > $1.key }
            .map({ "\($0.key):\($0.value)" })
            .joined(separator: "\n")
        
        return "\n\(text)\n"
    }
    
    /// 分割字符串，等号两边分别是键名和键值
    private func split(_ text: String) -> (String, String)? {
        let items = text.components(separatedBy: "=")
        guard items.count > 1 else {
            return nil
        }
        return (items[0], items[1])
    }
}
