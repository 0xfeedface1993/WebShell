//
//  File.swift
//  
//
//  Created by john on 2023/7/4.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct CookieMaster {
    let session: URLSession
    let cookies: HTTPCookieStorage
    
    init(session: URLSession, cookies: HTTPCookieStorage) {
        self.session = session
        self.cookies = cookies
    }
    
    init(_ delegator: URLSessionDelegator) {
        let configure = URLSessionConfiguration.ephemeral
        configure.timeoutIntervalForRequest = 20 * 60
        configure.timeoutIntervalForResource = 15 * 24 * 3600
        let cookies = HTTPCookieStorage()
        configure.httpCookieStorage = cookies
        
        self.session = URLSession(configuration: configure, delegate: delegator, delegateQueue: nil)
        self.cookies = cookies
    }
    
    func clearAllCookies() {
        cookies.removeCookies(since: .distantPast)
        logger.info("remove cookies in .distanPast")
    }
}
