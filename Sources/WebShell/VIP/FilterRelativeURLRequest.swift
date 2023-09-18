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
    public typealias Input = [URLRequestBuilder]
    public typealias Output = [URLRequestBuilder]

    /// The prefix of url, default is `http`, almost scheme
    public let prefix: String
    
    public init(_ prefix: String = "http") {
        self.prefix = prefix
     }
    
    public func execute(for inputValue: [URLRequestBuilder]) async throws -> [URLRequestBuilder] {
        let requests = inputValue
        let next = requests.compactMap({ $0.url?.hasPrefix(prefix) ?? false })
        let diff = requests.count - next.count
        if diff > 0 {
            shellLogger.info("\(diff) requests filtered by non-prefix [\(prefix)], \(requests.compactMap { $0.url })")
        }
        return inputValue
    }
}
