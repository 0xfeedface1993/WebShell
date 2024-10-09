//
//  File.swift
//  
//
//  Created by john on 2023/9/12.
//

import Foundation
import Durex

public struct SignInDownPageRequest: Dirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public init() {}

    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        let fileid = try await inputValue.string(.fileid)
        let lastRequest = try await inputValue.request(.lastRequest)
        guard let url = lastRequest.url else {
            throw ShellError.badURL(lastRequest.url ?? "")
        }
        let (host, scheme) = try url.baseComponents()
        let refer = "\(scheme)://\(host)/down2-\(fileid).html"
        let request = try Request(scheme: scheme, host: host, fileid: fileid, refer: refer).make()
        return inputValue.assign(request, forKey: .output)
    }
    
    struct Request {
        let scheme: String
        let host: String
        let fileid: String
        let refer: String
        
        func make() throws -> URLRequestBuilder {
            DownPageCustomHeaderRequest(scheme: scheme, host: host, fileid: fileid).make({
                $0.add(value: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forKey: "accept")
                    .add(value: "en-US,en;q=0.9", forKey: "accept-language")
                    .add(value: userAgent, forKey: "user-agent")
                    .add(value: refer, forKey: "referer")
            })
        }
    }
}
