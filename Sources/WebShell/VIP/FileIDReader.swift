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
        let url = try await inputValue.string(.fileidURL)
        let fileid = try finder.extract(url)
        return inputValue
            .assign(fileid, forKey: .fileid)
            .assign(fileid, forKey: .output)
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
        try await FindStringInFile(.htmlFile, forKey: .fileid, finder: finder)
            .join(CopyOutValue(.fileid, to: .code))
            .execute(for: inputValue)
    }
}
