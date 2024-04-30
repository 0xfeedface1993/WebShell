//
//  File.swift
//  
//
//  Created by amd on 2023/12/20.
//

import Foundation
import Durex

public struct HostDifferFilter: Dirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    static let cache = HostDifferCache()
    
    public init() {}
    
    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        let requests = try inputValue.requests(.output)
        var options = [URLRequestBuilder]()
        for request in requests {
            guard let host = try? request.url?.baseComponents().host else {
                continue
            }
            if await HostDifferFilter.cache.validate(host) {
                options.append(request)
            }
        }
        return inputValue.assign(options, forKey: .output)
    }
}

actor HostDifferCache {
    private var store = [AnyHashable: Int]()
    
    func push<Key: Hashable>(_ key: Key) {
        store[key] = 1
    }
    
    func pop<Key: Hashable>(_ key: Key) {
        store[key] = 0
    }
    
    func validate<Key: Hashable>(_ key: Key) -> Bool {
        (store[key] ?? 0) > 0
    }
}
