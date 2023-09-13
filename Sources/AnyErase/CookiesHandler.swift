//
//  File.swift
//  
//
//  Created by john on 2023/9/5.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct CookiesHandler {
    let request: URLRequest
    let response: URLResponse
    let session: URLSession
    
    func setCookies() {
        let allHeaderFields = (response as? HTTPURLResponse)?.allHeaderFields ?? [:]
        let headers = stringPairs(allHeaderFields)
        logger.info("response Set-Coookies: \(headers)")
        if let host = request.url?.removeURLPath() {
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: host)
            logger.info("found \(cookies.count) cookies for \(host), try set it.")
            session.configuration.httpCookieStorage?.setCookies(cookies, for: host, mainDocumentURL: nil)
            logger.info("set-cookies status: \(CookiesReader(session).sortCookiesDescription())")
        }   else    {
            logger.warning("invalid url for \(request).")
        }
    }
    
    @inlinable
    func stringPairs(_ rawHeader: [AnyHashable: Any]) -> [String: String] {
        let lists: [(String, String)] = rawHeader.compactMap({
            guard let key = $0.key as? String, let value = $0.value as? String else {
                return nil
            }
            return (key, value)
        })
        
        var headers = [String: String]()
        for (key, value) in lists {
            headers[key] = value
        }
        return headers
    }
}

extension URL {
    public func removeURLPath() -> URL {
        var next = self
        next.deletePathExtension()
        return next
    }
}
