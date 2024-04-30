//
//  Combine+Task.swift
//  WebShellExsample
//
//  Created by john on 2023/3/29.
//  Copyright © 2023 ascp. All rights reserved.
//

import Foundation
import Logging

#if COMBINE_LINUX && canImport(CombineX)
import CombineX
#else
import Combine
#endif

#if canImport(Durex)
import Durex
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
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
    /// 没有下载链接
    case noDownloadFiles
    /// 验证码长度错误
    case invalidCode(String)
    /// 没有验证码解析模块
    case noCodeReader
}

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
