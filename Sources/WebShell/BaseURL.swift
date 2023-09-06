//
//  File.swift
//  
//
//  Created by john on 2023/9/6.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct BaseURL {
    let url: URL?
    
    func domainURL() -> String {
        url?.removeURLPath().absoluteString ?? ""
    }
    
    func replaceHost(_ otherURL: URL) -> URL? {
        guard let url = url else {
#if DEBUG
            shellLogger.error("replace url failed. nil url")
#endif
            return nil
        }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
#if DEBUG
            shellLogger.error("replace url failed. use origin \(url)")
#endif
            return url
        }
        
        guard let next = components.url(relativeTo: otherURL) else {
#if DEBUG
            shellLogger.error("replace url failed. use origin \(url)")
#endif
            return url
        }
        
        return next
    }
}
