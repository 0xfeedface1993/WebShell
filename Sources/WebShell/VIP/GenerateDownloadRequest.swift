//
//  File.swift
//  WebShell
//
//  Created by york on 2025/9/4.
//

import Foundation
import Durex

public struct GenerateDownloadRequest {
    public let fileURL: String
    public let fileID: String
    public let xsrf: String?
    public let csrf: String?
    
    public func builder() -> URLRequestBuilder {
        guard let components = URLComponents(string: fileURL),
                let scheme = components.scheme,
                let host = components.host else {
            return URLRequestBuilder()
        }
        let url = "\(scheme)://\(host)/f/\(fileID)/generate-download"
        let body: Data
        do {
            body = try JSONEncoder().encode(XRCFVIPDownloadURLRequest.default)
        } catch {
            return URLRequestBuilder()
        }
        return URLRequestBuilder(
            url: url,
            method: .post,
            headers: nil,
            body: body
        )
        .add(.keepAliveConnection)
        .add(.jsonContentType)
        .add(value: csrf, forKey: .xCSRFToken)
        .add(value: xsrf, forKey: .xXSRFToken)
    }
    
    public init(fileURL: String, fileID: String, xsrf: String?, csrf: String?) {
        self.fileURL = fileURL
        self.fileID = fileID
        self.xsrf = xsrf
        self.csrf = csrf
    }
    
    public init(_ store: KeyStore) async throws {
        try await self.init(
            fileURL: store.string(.fileidURL),
            fileID: store.string(.fileid),
            xsrf: store.cookie(.xsrf).value.removingPercentEncoding,
            csrf: store.string(.csrf)
        )
    }
}
