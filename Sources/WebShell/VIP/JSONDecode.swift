//
//  File.swift
//  WebShell
//
//  Created by york on 2025/9/5.
//

import Foundation
import Durex

@inlinable
public func decode<T: Codable>(_ store: KeyStore, key: KeyStore.Key = .htmlFile) async throws -> T {
    let url = try await store.url(key)
    let jsonDecoder = JSONDecoder()
    let data = try Data(contentsOf: url)
    return try jsonDecoder.decode(T.self, from: data)
}
