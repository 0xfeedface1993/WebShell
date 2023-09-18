//
//  File.swift
//  
//
//  Created by john on 2023/9/18.
//

import Foundation
import Durex

/// Filter relative url request
public struct FilterRelativeURLRequest: Dirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore

    /// The prefix of url, default is `http`, almost scheme
    public let prefix: String
    
    public init(_ prefix: String = "http") {
        self.prefix = prefix
     }
    
    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        let requests = try inputValue.requests(.output)
        let next = requests.compactMap({ $0.url?.hasPrefix(prefix) ?? false })
        let diff = requests.count - next.count
        if diff > 0 {
            shellLogger.info("\(diff) requests filtered by non-prefix [\(prefix)], \(requests.compactMap { $0.url })")
        }
        return inputValue
            .assign(next, forKey: .output)
    }
}
