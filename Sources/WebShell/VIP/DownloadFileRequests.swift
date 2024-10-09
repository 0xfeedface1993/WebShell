//
//  File.swift
//  
//
//  Created by john on 2023/9/21.
//

import Foundation
import Durex

public struct DownloadFileRequests: Dirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public let builder: DownloadRequestBuilder
    public let from: KeyStore.Key
    public let to: KeyStore.Key
    
    public init(_ from: KeyStore.Key = .output, builder: DownloadRequestBuilder, to: KeyStore.Key = .output) {
        self.builder = builder
        self.from = from
        self.to = to
    }

    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        let links = try await inputValue.strings(from)
        let lastRequest = try await inputValue.request(.lastRequest)
        let refer = lastRequest.url ?? ""
        let requests = links.map {
            builder.make($0, refer: refer)
        }
        return inputValue.assign(requests, forKey: to)
    }
}
