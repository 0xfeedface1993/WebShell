//
//  WebShellError.swift
//  WebShellExsample
//
//  Created by JohnConner on 2020/6/23.
//  Copyright © 2020 ascp. All rights reserved.
//

import Foundation

public enum WebShellError: Error {
    public enum RequestReason {
        case emptyRequest
        case invalidateURL(request: URLRequest)
    }
    
    public enum ReponseReason {
        case invalidURLResponse(response: URLResponse)
        case invalidHTTPStatusCode(response: HTTPURLResponse)
        case URLSessionError(error: Error)
    }
}
