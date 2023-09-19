//
//  File.swift
//  
//
//  Created by john on 2023/9/12.
//

import Foundation
import Durex

public struct FileIDReader<T: FileIDFinder>: Dirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public let finder: T
    
    public init(finder: T) {
        self.finder = finder
    }

    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        let url = try inputValue.string(.fileidURL)
        let fileid = try finder.extract(url)
        return inputValue
            .assign(fileid, forKey: .fileid)
            .assign(fileid, forKey: .output)
    }
}

public struct FileIDURLReader: Dirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public init() {
        
    }

    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        let url = try inputValue.string(.output)
        return inputValue.assign(url, forKey: .fileidURL)
    }
}

public struct FileIDInDomReader<F: FileIDFinder>: Dirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public let finder: F
    
    public init(_ finder: F) {
        self.finder = finder
    }

    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        let file = try inputValue.url(.htmlFile)
        let text = try String(contentsOf: file, encoding: .utf8)
        let fiieid = try finder.extract(text)
        return inputValue
            .assign(fiieid, forKey: .fileid)
            .assign(fiieid, forKey: .output)
    }
}
