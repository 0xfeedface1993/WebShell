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

    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        let fileid = try inputValue.string(.fileid)
        let lastRequest = try inputValue.request(.lastRequest)
        guard let url = lastRequest.url else {
            throw ShellError.badURL(lastRequest.url ?? "")
        }
        let (host, scheme) = try url.baseComponents()
        let request = try Request(scheme: scheme, host: host, fileid: fileid, refer: url).make()
        return inputValue.assign(request, forKey: .lastOutput)
    }
    
    struct Request {
        let scheme: String
        let host: String
        let fileid: String
        let refer: String
        
        func make() throws -> URLRequestBuilder {
            DownPageCustomHeaderRequest(scheme: scheme, host: host, fileid: fileid).make({
                $0.add(value: "application/x-www-form-urlencoded", forKey: "content-type")
                    .add(value: "text/plain, */*", forKey: "accept")
                    .add(value: "XMLHttpRequest", forKey: "x-requested-with")
                    .add(value: "en-US,en;q=0.9", forKey: "accept-language")
                    .add(value: "\(scheme)://\(host)", forKey: "origin")
                    .add(value: userAgent, forKey: "user-agent")
                    .add(value: refer, forKey: "referer")
            })
        }
    }
}
