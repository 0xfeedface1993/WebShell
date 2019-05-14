//
//  TBParser.swift
//  WebShell_macOS
//
//  Created by virus1994 on 2019/5/9.
//  Copyright © 2019 ascp. All rights reserved.
//

import Cocoa

struct TBParser {
    var parsers = [TBParserUnit]()
    static func parser(item: TBQueueItem) -> TBParser {
        switch item.site {
        case .xunniu:
            let urlPaser = XNURLParser()
            urlPaser.value = item.url as AnyObject
            let finder = XNFinderParser()
            return TBParser(parsers: [urlPaser, finder])
        default:
            return TBParser(parsers: [])
        }
    }
}

protocol TBParserUnit: class {
    var value: AnyObject? { get set }
    var passValue: AnyObject? { get set }
    var escape: ((TBParserUnit) -> Void)? { get set }
//    var dataTask: URLSessionTask? { get set }
    func execute(completion: @escaping (TBParserUnit) -> ())
}

extension Array: Logger where Element == TBParserUnit {
    func next(unit: TBParserUnit) {
        guard let index = self.firstIndex(where: { item in
            var flag = false
            withUnsafePointer(to: item, { (x) in
                withUnsafePointer(to: unit, { (y) in
                    flag = x == y
                })
            })
            return flag
        }) else {
             log(message: "No unit fit \(unit).")
            return
        }
        
        if self.endIndex == index {
            log(message: "Already last unit.")
            return
        }
        
        let nextIndex = self.index(after: index)
        self[nextIndex].value = self[index].passValue
        self[nextIndex].execute { (x) in
            self.next(unit: x)
        }
    }
    
    func run() {
        if let x = self.first {
            x.execute(completion: { (y) in
                self.next(unit: y)
            })
        }
    }
}

class XNURLParser: TBParserUnit, Logger {
//    var dataTask: URLSessionTask?
    
    var value: AnyObject?
    var passValue: AnyObject?
    var escape: ((TBParserUnit) -> Void)?
    
    func execute(completion: @escaping (TBParserUnit) -> ()) {
        guard let regx = try? NSRegularExpression(pattern: "\\d{5,}", options: NSRegularExpression.Options.caseInsensitive) else {
            log(error: "Invalid Regular Expression.")
            escape?(self)
            return
        }
        
        guard let str = value as? String else {
            log(error: "Data not String value. \(value?.description ?? "nil")")
            escape?(self)
            return
        }
        
        let strNS = str as NSString
        guard let result = regx.firstMatch(in: str, options: NSRegularExpression.MatchingOptions.reportProgress, range: NSRange(location: 0, length: strNS.length)) else {
            log(error: "Can't find file Number.")
            escape?(self)
            return
        }
        
        let fileNumber = strNS.substring(with: result.range)
        log(message: "File number found: \(fileNumber)")
        
        passValue = fileNumber as AnyObject
        completion(self)
    }
}

final class XNFinderParser: TBParserUnit, Logger {
//    var dataTask: URLSessionTask?
    var value: AnyObject?
    var passValue: AnyObject?
    var escape: ((TBParserUnit) -> Void)?
    
    let hostName = "www.xun-niu.com"
    
    func execute(completion: @escaping (TBParserUnit) -> ()) {
        guard let fileNumber = value as? String else {
            log(error: "Data not String value. \(value?.description ?? "nil")")
            escape?(self)
            return
        }
        
        let url = URL(string: "http://\(hostName)/ajax.php")!
        let headFields = [
            "Host":hostName,
            "Accept":"text/plain, */*; q=0.01",
            "X-Requested-With":"XMLHttpRequest",
            "Accept-Language":"zh-cn",
            "Accept-Encoding":"gzip, deflate",
            "Content-Type":"application/x-www-form-urlencoded; charset=UTF-8",
            "Origin":hostName,
            "User-Agent":userAgent,
            "Referer":"http://\(hostName)/down-\(fileNumber).html",
            "Connection":"keep-alive"
        ]
        
        var req = URLRequest(url: url)
        req.httpShouldHandleCookies = true
        req.httpMethod = "POST"
        req.timeoutInterval = 5 * 60
        for item in headFields {
            req.addValue(item.value, forHTTPHeaderField: item.key)
        }
        req.httpBody = "action=load_down_addr1&file_id=\(fileNumber)".data(using: .utf8, allowLossyConversion: false)
        let task = URLSession.shared.dataTask(with: req) { (d, r, err) in
            if let e = err {
                self.log(error: "Network error: \(e.localizedDescription)")
                self.escape?(self)
                return
            }
            
            guard let data = d else {
                self.log(error: "Data is nil.")
                self.escape?(self)
                return
            }
            
            guard let str = String(data: data, encoding: .utf8) else {
                self.log(error: "Data not String. \(data.description)")
                self.escape?(self)
                return
            }
            
            self.passValue = str as AnyObject
            completion(self)
        }
        task.resume()
    }
}

