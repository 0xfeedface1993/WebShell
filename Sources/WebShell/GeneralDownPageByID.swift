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

#if COMBINE_LINUX && canImport(CombineX)
import CombineX
#else
import Combine
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// 基于fileid构造下载链接页面请求
public struct GeneralDownPageByID: Condom {
    public typealias Input = String
    public typealias Output = URLRequest
    
    let scheme: String
    let host: String
    let refer: String
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        Future {
            try await AsyncGeneralDownPageByID(scheme: scheme, host: host, refer: refer).execute(for: inputValue).build()
        }
        .eraseToAnyPublisher()
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Empty().eraseToAnyPublisher()
    }
}

public struct AsyncGeneralDownPageByID: Dirtyware {
    public typealias Input = String
    public typealias Output = URLRequestBuilder
    
    let scheme: String
    let host: String
    let refer: String
    
    public func execute(for inputValue: String) async throws -> URLRequestBuilder {
        GeneralDownPage(scheme: scheme, fileid: inputValue, host: host, refer: refer).make()
    }
}
