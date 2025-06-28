//
//  WebShellError.swift
//  WebShellExsample
//
//  Created by JohnConner on 2020/6/23.
//  Copyright © 2020 ascp. All rights reserved.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum WebShellError: Error, Sendable {
    public enum RequestReason {
        case emptyRequest
        case invalidateURL(request: URLRequest)
    }
    
    public enum ReponseReason {
        case invalidURLResponse(response: URLResponse)
        case invalidHTTPStatusCode(response: HTTPURLResponse)
        case URLSessionError(error: Error)
        case unknown
    }
}

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
    /// 没有有效的下载的页链接
    case noPageLink
    /// 帐号密码不正确
    case invalidAccount(username: String)
    /// 用户没有付费
    case unpaidUser(username: String)
}
