//
//  AccountValidateViewModel.swift
//  WebShellExsample
//
//  Created by york on 2025/9/5.
//  Copyright © 2025 ascp. All rights reserved.
//

import Foundation

@Observable
final class AccountValidateViewModel {
    var itemModels = [AccountModel]()
}

struct AccountModel {
    
}

struct AccountValidateConfiguration {
    let hasCodeVerify: Bool
    
}

enum AccountValidateState {
    case none
    case account(username: String, password: String)
    case redirectURL(fileURL: URL)
    case updatedURL(fileURL: URL)
    case requiredVerifyCode(fileURL: URL, username: String, password: String, )
    case verifyCodeDone(fileURL: URL, username: String, password: String, code: String)
    case login(fileURL: URL, username: String, password: String)
    case done(fileURL: URL, username: String, password: String)
}
