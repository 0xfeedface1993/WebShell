//
//  Combine+Task.swift
//  WebShellExsample
//
//  Created by john on 2023/3/29.
//  Copyright © 2023 ascp. All rights reserved.
//

import Foundation
import Combine
import Logging
#if canImport(Durex)
import Durex
#endif

internal let shellLogger = Logger(label: "com.ascp.webshell")

public enum ShellError: Error {
    /// url为空或者不正确
    case badURL(String?)
    /// 网络请求空数据
    case emptyData
    /// 网络请求生成失败，没有抓到有效的信息生成
    case emptyRequest
    /// 文件不存在
    case fileNotExist(URL)
    /// 保存位置异常，无法保存
    case invalidDestination
    /// 文件id读取失败
    case noFileID
    /// Data转文本失败
    case decodingFailed(String.Encoding)
    /// 重定向
    case redirect(URL)
    /// 没有正则匹配
    case regulaNotMatch(String)
}

//extension URLSession {
//    /// 封装URLSession.shared.dataTask(with:) 成publisher
//    /// - Parameter request: 网络请求
//    /// - Returns: 异步结果，这里目前只取Data
//    public func dataTask(_ request: URLRequest) -> Future<Data, Error> {
//        Future { promise in
//            self.dataTask(with: request) { data, response, error in
//                if let error = error {
//                    promise(.failure(error))
//                    return
//                }
//                
//                guard let data = data else {
//                    promise(.failure(ShellError.emptyData))
//                    return
//                }
//                
//                promise(.success(data))
//            }.resume()
//        }
//    }
//    
//    /// 封装URLSession.shared.downloadTask(with:) 成publisher
//    /// - Parameter request: 网络请求
//    /// - Returns: 异步结果，这里目前取Data和URLResponse，response里面使用suggestedFilename读取文件名
//    public func downloadTask(_ request: URLRequest) -> Future<(URL, URLResponse), Error> {
//        Future { promise in
//            self.downloadTask(with: request, completionHandler: { url, response, error in
//                if let error = error {
//                    promise(.failure(error))
//                    return
//                }
//                
//                guard let url = url, let response = response else {
//                    promise(.failure(ShellError.emptyData))
//                    return
//                }
//                
//                promise(.success((url, response)))
//            }).resume()
//        }
//    }
//}

#if DEBUG
extension Publisher {
    /// 只是为了打印错误信息
    func logError() -> Publishers.MapError<Self, Failure> {
        let debug = "\(self)"
        return mapError { error in
            shellLogger.error("[combine error stub] \(error), in \(debug)")
            return error
        }
    }
}
#endif

extension Array: ContextValue where Element == URLRequest {
    public var valueDescription: String {
        "\(self)"
    }
}
