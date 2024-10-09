//
//  File.swift
//  
//
//  Created by john on 2023/9/19.
//

import Foundation
import Durex

public struct AjaxFileListPageRequest: Dirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    let action: String
    
    public init(_ action: String) {
        self.action = action
    }
     
    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        let fileid = try await inputValue.string(.fileid)
        let refer = try await inputValue.string(.fileidURL)
        let (host, scheme) = try refer.baseComponents()
        let request = ReferDownPageRequest(fileid: fileid, refer: refer, scheme: scheme, host: host, action: action).make()
        return inputValue.assign(request, forKey: .output)
    }
}
