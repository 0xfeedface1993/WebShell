//
//  Combine+Task.swift
//  WebShellExsample
//
//  Created by john on 2023/3/29.
//  Copyright © 2023 ascp. All rights reserved.
//

import Foundation
import Logging

#if COMBINE_LINUX && canImport(CombineX)
import CombineX
#else
import Combine
#endif

#if canImport(Durex)
import Durex
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

internal let shellLogger = Logger(label: "com.ascp.webshell")

#if DEBUG
extension Publisher {
    /// 只是为了打印错误信息
    func logError() -> Publishers.MapError<Self, Failure> {
        let debug = "\(self)"
        return mapError { error in
            shellLogger.error("[combine error stub] \(error), in \(debug)")
            return error
        }
    }
}
#endif
