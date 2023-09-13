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
import AnyErase

struct URLSessionHolder {
    let session: any URLClient
    let cookies: HTTPCookieStorage
    
    init(session: any URLClient, cookies: HTTPCookieStorage) {
        self.session = session
        self.cookies = cookies
    }
    
    init(_ delegator: URLSessionDelegator) {
//        let configure = URLSessionConfiguration.default
//        configure.timeoutIntervalForRequest = 20 * 60
//        configure.timeoutIntervalForResource = 15 * 24 * 3600
////        let cookies = HTTPCookieStorage()
////        configure.httpCookieStorage = cookies
//        configure.httpCookieStorage?.removeCookies(since: Date(timeIntervalSinceReferenceDate: 0))
//        configure.httpCookieStorage?.cookieAcceptPolicy = .always
//        configure.httpShouldSetCookies = true
//
//        self.session = URLSession(configuration: configure, delegate: delegator, delegateQueue: nil)
//        if let storage = configure.httpCookieStorage {
//            self.cookies = storage
//        }   else    {
//            let message = "empty httpCookieStorage in configure \(configure)."
//            logger.error(.init(stringLiteral: message))
//            fatalError(message)
//        }
        self.session = URLSession.shared
        if let storage = URLSession.shared.configuration.httpCookieStorage {
            self.cookies = storage
        }   else    {
            let message = "empty httpCookieStorage in shared \(URLSession.shared)."
            logger.error(.init(stringLiteral: message))
            fatalError(message)
        }
    }
    
    init(_ delegate: any AsyncURLSessiobDownloadDelegate) {
//        let configure = URLSessionConfiguration.default
//        configure.timeoutIntervalForRequest = 20 * 60
//        configure.timeoutIntervalForResource = 15 * 24 * 3600
//        configure.httpCookieStorage?.removeCookies(since: Date(timeIntervalSinceReferenceDate: 0))
//        configure.httpCookieStorage?.cookieAcceptPolicy = .always
//        configure.httpShouldSetCookies = true
//
//        self.session = URLSession(configuration: configure, delegate: delegate, delegateQueue: OperationQueue())
//        if let storage = configure.httpCookieStorage {
//            self.cookies = storage
//        }   else    {
//            let message = "empty httpCookieStorage in configure \(configure)."
//            logger.error(.init(stringLiteral: message))
//            fatalError(message)
//        }
        
        self.session = URLSession.shared
        if let storage = URLSession.shared.configuration.httpCookieStorage {
            self.cookies = storage
        }   else    {
            let message = "empty httpCookieStorage in shared \(URLSession.shared)."
            logger.error(.init(stringLiteral: message))
            fatalError(message)
        }
    }
    
    func clearAllCookies() {
        cookies.removeCookies(since: .distantPast)
        logger.info("remove cookies in .distanPast")
    }
}
