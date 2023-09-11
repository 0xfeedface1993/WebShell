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

    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        let url = try inputValue.string(.fileidURL)
        let fileid = try finder.extract(url)
        return inputValue
            .assign(fileid, forKey: .fileid)
            .assign(fileid, forKey: .lastOutput)
    }
}
