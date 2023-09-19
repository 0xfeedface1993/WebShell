//
//  File.swift
//  
//
//  Created by john on 2023/9/19.
//

import Foundation
import Durex

public struct FindStringInFile: Dirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public let key: KeyStore.Key
    public let source: KeyStore.Key
    public let finder: FileIDFinder
    
    public init(_ source: KeyStore.Key, forKey key: KeyStore.Key, finder: FileIDFinder) {
        self.key = key
        self.source = source
        self.finder = finder
    }
    
    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        let url = try inputValue.url(source)
        let string = try String(contentsOf: url, encoding: .utf8)
        let target = try finder.extract(string)
        return inputValue
            .assign(target, forKey: key)
            .assign(target, forKey: .output)
    }
}
