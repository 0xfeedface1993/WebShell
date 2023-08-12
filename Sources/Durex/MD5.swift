//
//  File.swift
//  
//
//  Created by john on 2023/8/5.
//

import Foundation

#if COMBINE_LINUX && canImport(CombineX)
import Crypto
#else
import CryptoKit
#endif

struct MD5Crypto {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    @inlinable
    func asciiString() -> String {
        text.unicodeScalars
            .map { String(format: "%d", $0.value) }
            .joined()
    }
    
    func asciiStringToMD5() -> String {
        let asciiString = asciiString()
        if let data = asciiString.data(using: .utf8) {
            let md5 = Insecure.MD5.hash(data: data).description
            let hash = md5.components(separatedBy: ": ").last ?? ""
            logger.info("text: \(text), asscii string: \(asciiString), md5 hash: \(hash)")
            return hash
        }
        logger.info("hash md5 failed, unable to convert utf8 data, text: \(text)")
        return ""
    }
}

extension String {
    /// 字符串转换成ASCII码字符串，再计算MD5值，返回MD5字符串小写结果
    public func asciiHexMD5String() -> String {
        MD5Crypto(self).asciiStringToMD5()
    }
}
