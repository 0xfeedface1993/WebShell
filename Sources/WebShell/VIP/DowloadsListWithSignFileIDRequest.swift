//
//  File.swift
//  
//
//  Created by john on 2023/9/12.
//

import Foundation
import Durex

public struct DowloadsListWithSignFileIDRequest: Dirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public let action: String
    
    public init(action: String) {
        self.action = action
    }

    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        let fileid = try await inputValue.string(.fileid)
        let lastRequest = try await inputValue.request(.lastRequest)
        let sign = try await inputValue.string(.sign)
        guard let url = lastRequest.url else {
            throw ShellError.badURL(lastRequest.url ?? "")
        }
        let (host, scheme) = try url.baseComponents()
        let request = ReferSignDownPageRequest(fileid: fileid, refer: url, scheme: scheme, host: host, action: action, sign: sign).make()
        return inputValue.assign(request, forKey: .output)
    }
}
