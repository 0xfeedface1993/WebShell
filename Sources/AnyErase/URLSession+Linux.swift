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

/// Defines the possible errors
public enum URLSessionAsyncErrors: Error {
    case invalidUrlResponse, missingResponseData, missingTmpFile
}

public protocol URLTask: AnyObject {
    var taskIdentifier: Int { get }
    func resume()
    func cancel()
}

extension URLSessionTask: URLTask {
    
}

/// An protocol that provides async support for fetching a URL
public protocol URLClient {
    func asyncData(from url: URLRequest) async throws -> (Data, URLResponse)
    /// download large file at tmp directory, not use custom delegate response
    func asyncDownload(from url: URLRequest) async throws -> (URL, URLResponse)
    /// create download task, 
    func asyncDataTask(from url: URLRequest) -> URLTask
}

/// An extension that provides async support for fetching a URL
///
/// Needed because the Linux version of Swift does not support async URLSession yet.
extension URLSession: URLClient {
    
    /// A reimplementation of `URLSession.shared.data(from: url)` required for Linux
    ///
    /// - Parameter url: The URL for which to load data.
    /// - Returns: Data and response.
    ///
    /// - Usage:
    ///
    ///     let (data, response) = try await URLSession.shared.asyncData(from: url)
    public func asyncData(from url: URLRequest) async throws -> (Data, URLResponse) {
        logger.info("\(url.curlString)")
        let result = try await _asyncData(from: url)
#if os(Linux)
        CookiesHandler(request: url, response: result.1, session: self).setCookies()
#endif
        return result
    }
    
    @usableFromInline
    func _asyncData(from url: URLRequest) async throws -> (Data, URLResponse) {
#if os(Linux)
        return try await withCheckedThrowingContinuation { continuation in
            let task = self.dataTask(with: url) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let response = response as? HTTPURLResponse else {
                    continuation.resume(throwing: URLSessionAsyncErrors.invalidUrlResponse)
                    return
                }
                guard let data = data else {
                    continuation.resume(throwing: URLSessionAsyncErrors.missingResponseData)
                    return
                }
                continuation.resume(returning: (data, response))
            }
            task.resume()
        }
#else
        return try await data(for: url)
#endif
    }
    
    public func asyncDownload(from url: URLRequest) async throws -> (URL, URLResponse) {
        logger.info("\(url.curlString)")
        let result = try await _asyncDownload(from: url)
#if os(Linux)
        CookiesHandler(request: url, response: result.1, session: self).setCookies()
#endif
        return result
    }
    
    @usableFromInline
    func _asyncDownload(from url: URLRequest) async throws -> (URL, URLResponse) {
#if os(Linux)
        return try await withCheckedThrowingContinuation { continuation in
            let task = self.dataTask(with: url) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let response = response as? HTTPURLResponse else {
                    continuation.resume(throwing: URLSessionAsyncErrors.invalidUrlResponse)
                    return
                }
                guard let data = data else {
                    continuation.resume(throwing: URLSessionAsyncErrors.missingResponseData)
                    return
                }
                continuation.resume(returning: (data, response))
            }
            task.resume()
        }
#else
        return try await defaultDownload(url)
#endif
    }
    
    @usableFromInline
    func defaultDownload(_ url: URLRequest) async throws -> (URL, URLResponse) {
        if #available(macOS 12.0, iOS 15.0, *) {
            return try await download(for: url)
        } else {
            // Fallback on earlier versions
            let curl = url.curlString
            return try await withCheckedThrowingContinuation { continuation in
                let task = downloadTask(with: url, completionHandler: { fileURL, response, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let response = response as? HTTPURLResponse else {
                        continuation.resume(throwing: URLSessionAsyncErrors.invalidUrlResponse)
                        return
                    }
                    guard let fileURL = fileURL else {
                        continuation.resume(throwing: URLSessionAsyncErrors.missingTmpFile)
                        return
                    }
                    
                    let filename = UUID().uuidString
                    let cachedURL = FileManager.default.temporaryDirectory
                    let location = cachedURL.appendingPathComponent(filename)
                    
                    do {
                        try FileManager.default.moveItem(at: fileURL, to: location)
                        logger.info("move tmp file to \(url)")
                        continuation.resume(returning: (location, response))
                    } catch {
                        logger.info("\(#function) download file failed \(error), curl: \(curl)")
                        continuation.resume(throwing: error)
                    }
                })
                task.resume()
            }
        }
    }
    
    public func asyncDataTask(from url: URLRequest) -> URLTask {
        dataTask(with: url)
    }
}

//#if os(Linux)
//extension URLSession {
//    /// A reimplementation of `URLSession.shared.data(from: url)` required for Linux
//    ///
//    /// - Parameter url: The URL for which to load data.
//    /// - Returns: Data and response.
//    ///
//    /// - Usage:
//    ///
//    ///     let (data, response) = try await URLSession.shared.asyncData(from: url)
//    public func data(for request: URLRequest) async throws -> (data: Data, response: URLResponse) {
//        try await asyncData(from: request)
//    }
//}
//#endif

public extension URLRequest {
    
    /// Returns a cURL command representation of this URL request.
    var curlString: String {
        guard let url = url else { return "" }
        var baseCommand = #"curl "\#(url.absoluteString)""#

        if httpMethod == "HEAD" {
            baseCommand += " --head"
        }

        var command = [baseCommand]

        if let method = httpMethod, method != "GET" && method != "HEAD" {
            command.append("-X \(method)")
        }

        if let headers = allHTTPHeaderFields {
            for (key, value) in headers where key != "Cookie" {
                command.append("-H '\(key): \(value)'")
            }
        }

        if let data = httpBody, let body = String(data: data, encoding: .utf8) {
            command.append("-d '\(body)'")
        }

        return command.joined(separator: " \\\n\t")
    }
    
}
