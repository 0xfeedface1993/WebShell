//
//  File.swift
//  
//
//  Created by john on 2023/9/19.
//

import Foundation
import Durex

public enum AjaxAction: Sendable {
    case checkCode
    case checkNoCode
    case custom(String)
    
    var description: String {
        switch self {
        case .checkCode, .checkNoCode:
            return "check_code"
        case .custom(let string):
            return string
        }
    }
}

public struct AjaxFileListPageRequest: Dirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    let action: AjaxAction
    
    public init(_ action: AjaxAction) {
        self.action = action
    }
     
    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
        let fileid = try await inputValue.string(.fileid)
        let refer = try await inputValue.string(.fileidURL)
        let (host, scheme) = try refer.baseComponents()
        switch action {
        case .checkCode, .checkNoCode:
            let code: String
            switch action {
            case .checkCode:
                code = try await inputValue.string(.code)
            case .checkNoCode:
                code = ""
            default:
                fatalError()
            }
            let request = FormDownloadLinksRequest(param: .checkCode(fileID: fileid, action: action.description, code: code), refer: refer, scheme: scheme, host: host)
            return inputValue.assign(request.make(), forKey: .output)
        case .custom(let string):
            let request = ReferDownPageRequest(fileid: fileid, refer: refer, scheme: scheme, host: host, action: string).make()
            return inputValue.assign(request, forKey: .output)
        }
    }
}
