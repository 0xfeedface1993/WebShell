//
//  UserInfoView.swift
//  WebShellExsample
//
//  Created by york on 2025/6/28.
//  Copyright © 2025 ascp. All rights reserved.
//

import SwiftUI

struct UserInfoView: View {
    var userInfo: UserInfo
    
    var body: some View {
        switch userInfo {
        case .logined(let username, let paid):
            VStack(alignment: .leading) {
                Text(username)
                Text(paid == .paid ? "付费用户":"免费")
                    .foregroundStyle(paid == .paid ? .green:.red)
            }
        case .unlogin(let username):
            Text("\(username) (未登录）")
                .frame(alignment: .leading)
        }
    }
}

#Preview {
    List {
        UserInfoView(userInfo: .logined(username: "demouser", paid: .paid))
        UserInfoView(userInfo: .logined(username: "demouser", paid: .unpaid))
        UserInfoView(userInfo: .logined(username: "demouser", paid: .paid))
    }
}

import WebShell

enum UserInfo: Equatable, Sendable {
    case logined(username: String, paid: PaidUser)
    case unlogin(username: String)
}
