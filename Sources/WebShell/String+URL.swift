//
//  String+URL.swift
//  WebShellExsample
//
//  Created by JohnConner on 2021/1/11.
//  Copyright © 2021 ascp. All rights reserved.
//

import Foundation

extension String {
    /// 若当前字符串是下载地址，则转义特殊字符
    var validURLString: String {
        var sets = CharacterSet.urlQueryAllowed
        sets.remove(charactersIn: "!*'();:@&=+$,/?%#[]")
        return addingPercentEncoding(withAllowedCharacters: sets) ?? ""
    }
}

public protocol URLValidator {
    /// 读取URL的host和scheme
    func baseComponents() throws -> (host: String, scheme: String)
}

extension String: URLValidator {
    public func baseComponents() throws -> (host: String, scheme: String) {
        guard let url = URL(string: self) else {
            throw ShellError.badURL(self)
        }
        return try url.baseComponents()
    }
}

extension URL: URLValidator {
    public func baseComponents() throws -> (host: String, scheme: String) {
        guard let component = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            throw ShellError.badURL(absoluteString)
        }
        
        guard let host = component.host, let scheme = component.scheme else {
            throw ShellError.badURL(absoluteString)
        }
        
        return (host, scheme)
    }
}
