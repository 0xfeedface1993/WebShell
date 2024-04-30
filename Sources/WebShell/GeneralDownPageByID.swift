//
//  File.swift
//  
//
//  Created by john on 2023/9/6.
//

import Foundation

#if canImport(Durex)
import Durex
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// 基于fileid构造下载链接页面请求
public struct GeneralDownPageByID: Dirtyware {
    public typealias Input = String
    public typealias Output = URLRequestBuilder
    
    let scheme: String
    let host: String
    let refer: String
    
    public func execute(for inputValue: String) async throws -> URLRequestBuilder {
        GeneralDownPage(scheme: scheme, fileid: inputValue, host: host, refer: refer).make()
    }
}
