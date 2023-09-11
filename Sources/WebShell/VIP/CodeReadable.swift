//
//  File.swift
//  
//
//  Created by john on 2023/9/12.
//

import Foundation
import Durex

/// 读取验证码，由外部使用者实现，有些库不能再macApp里面使用，所以交给外部，苹果平台的话就用Vision框架
public protocol CodeReadable {
    func code(_ data: Data) async throws -> String
}
