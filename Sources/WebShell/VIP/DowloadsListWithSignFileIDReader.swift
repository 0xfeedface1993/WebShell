//
//  File.swift
//  
//
//  Created by john on 2023/9/12.
//

import Foundation
import Durex

public struct DowloadsListWithSignFileIDReader: SessionableDirtyware {
    public typealias Input = KeyStore
    public typealias Output = KeyStore
    
    public var key: AnyHashable
    public var configures: AsyncURLSessionConfiguration
    
    public init(_ configures: AsyncURLSessionConfiguration, key: AnyHashable) {
        self.key = key
        self.configures = configures
    }
    
    public func execute(for inputValue: KeyStore) async throws -> KeyStore {
//        let request = try inputValue.request(.output)
//        guard let url = request.url else {
//            throw ShellError.badURL(request.url ?? "")
//        }
//        let (host, scheme) = try url.baseComponents()
//        let links = try await FindStringsInDomSearch(FileIDMatch.href, configures: configures, key: key).execute(for: request)
//        let refer = "\(scheme)://\(host)"
//        let maker = SignPHPFileDownload()
//        let next = links.map {
//            maker.make($0, refer: refer)
//        }
//        
//        return inputValue
//            .assign(next, forKey: .output)
//            .assign(request, forKey: .lastRequest)
        try await URLRequestPageReader(.output, configures: configures, key: key)
            .join(FindStringInFile(.htmlFile, forKey: .output, finder: .href))
            .join(
                DownloadFileRequests(builder: SignPHPFileDownload())
            )
            .execute(for: inputValue)
    }
    
    public func sessionKey(_ value: AnyHashable) -> Self {
        .init(configures, key: value)
    }
}

