//
//  File.swift
//  
//
//  Created by john on 2023/3/15.
//

import Foundation

#if COMBINE_LINUX && canImport(CombineX)
import CombineX
#else
import Combine
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum URLRequestBuilderError: Error, LocalizedError {
    case badURL(String?)
    
    public var errorDescription: String? {
        switch self {
        case .badURL(let string):
            return "bad url string for \(string ?? "nil")"
        }
    }
}

extension URLRequest: ContextValue {
    @inlinable
    public var valueDescription: String {
        description
    }
    
    public func cURL(pretty: Bool = false) -> String {
        let newLine = pretty ? "\\\n" : ""
        let method = (pretty ? "--request " : "-X ") + "\(self.httpMethod ?? "GET") \(newLine)"
        let url: String = (pretty ? "--url " : "") + "\'\(self.url?.absoluteString ?? "")\' \(newLine)"
        
        var cURL = "curl "
        var header = ""
        var data: String = ""
        
        if let httpHeaders = self.allHTTPHeaderFields, httpHeaders.keys.count > 0 {
            for (key,value) in httpHeaders {
                header += (pretty ? "--header " : "-H ") + "\'\(key): \(value)\' \(newLine)"
            }
        }
        
        if let bodyData = self.httpBody, let bodyString = String(data: bodyData, encoding: .utf8),  !bodyString.isEmpty {
            data = "--data '\(bodyString)'"
        }
        
        cURL += method + url + header + data
        
        return cURL
    }
}

public struct URLRequestBuilder {
    public let url: String?
    public let method: Method
    public let headers: [String: String]?
    public let body: Data?
    
    public init(_ urlString: String? = nil) {
        self.url = urlString
        self.method = .get
        self.headers = nil
        self.body = nil
    }
    
    public init(url: String?, method: Method = .get, headers: [String : String]?, body: Data?) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }
    
    public func url(_ value: String) -> URLRequestBuilder {
        URLRequestBuilder(url: value, method: method, headers: headers, body: body)
    }

    public func method(_ value: Method) -> URLRequestBuilder {
        URLRequestBuilder(url: url, method: value, headers: headers, body: body)
    }
    
    public func headers(_ value: [String: String]) -> URLRequestBuilder {
        URLRequestBuilder(url: url, method: method, headers: value, body: body)
    }
    
    public func body(_ value: Data) -> URLRequestBuilder {
        URLRequestBuilder(url: url, method: method, headers: headers, body: value)
    }
    
    public func add(value: String, forKey key: String) -> URLRequestBuilder {
        var temp = headers ?? [:]
        temp[key] = value
        return URLRequestBuilder(url: url, method: method, headers: temp, body: body)
    }
    
    public func build() throws -> URLRequest {
        guard let urlString = url, let url = URL(string: urlString) else {
            throw URLRequestBuilderError.badURL(url)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue
        urlRequest.httpBody = body
        headers?.forEach({ pair in
            urlRequest.addValue(pair.value, forHTTPHeaderField: pair.key)
        })
        
        return urlRequest
    }
    
    public func condom() throws -> Request {
        Request(self)
    }
    
    public enum Method: String {
        case get = "GET"
        case post = "POST"
    }
}

extension URLRequestBuilder: ContextValue {
    public var valueDescription: String {
        """
        url: \(url ?? "")
        method: \(method)
        headers: \(headers ?? [:])
        body: \(body?.count ?? 0) bytes
        """
    }
}

public protocol URLRequestProvider {
    /// 生成URLRequest
    func accept(_ value: any URLRequestComsumer) throws -> URLRequest
}

/// 给URLRequestProvider提供数据，一般是url字符串String
public protocol URLRequestComsumer {
    func readURL() -> String?
}

extension URLRequest: URLRequestProvider {
    /// 无需新生成，直接返回自身
    /// - Parameter value: 提供URLRequest生成参数提供者
    /// - Returns: 新网络请求
    @inlinable
    public func accept(_ value: URLRequestComsumer) throws -> URLRequest {
        self
    }
}

extension URLRequestBuilder: URLRequestProvider {
    /// 更换新URL，生成新URLRequest
    /// - Parameter value: 提供URLRequest生成参数提供者，这里读取url字符串
    /// - Returns: 新网络请求
    public func accept(_ value: URLRequestComsumer) throws -> URLRequest {
        try url(value.readURL() ?? "").build()
    }
}

extension String: ContextValue, URLRequestComsumer {
    @inlinable
    public var valueDescription: String {
        self
    }
    
    @inlinable
    public func readURL() -> String? {
        self
    }
}

/// 输入两种情况：
///     1. 直接指定URLRequest，内部无需配置生成
///     2. 取输入数据，使用 `URLRequestBuilder` 生成URLRequest
public struct Request: Condom {
    public typealias Input = String
    public typealias Output = URLRequest
    let prorider: URLRequestProvider
    
    public init(_ provider: URLRequestProvider) {
        self.prorider = provider
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        do {
            let request = try prorider.accept(inputValue)
            return AnyValue(request)
                .eraseToAnyPublisher()
        }   catch   {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
}
