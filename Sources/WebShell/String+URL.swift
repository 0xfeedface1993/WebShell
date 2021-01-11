//
//  String+URL.swift
//  WebShellExsample
//
//  Created by JohnConner on 2021/1/11.
//  Copyright © 2021 ascp. All rights reserved.
//

import Foundation

extension String {
    /// 若当前字符串是下载地址，则转义特殊字符
    var validURLString: String {
        var sets = CharacterSet.urlQueryAllowed
        sets.remove(charactersIn: "!*'();:@&=+$,/?%#[]")
        return addingPercentEncoding(withAllowedCharacters: sets) ?? ""
    }
}
