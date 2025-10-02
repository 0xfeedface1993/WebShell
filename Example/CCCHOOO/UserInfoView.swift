//
//  UserInfoView.swift
//  WebShellExsample
//
//  Created by york on 2025/6/28.
//  Copyright © 2025 ascp. All rights reserved.
//

import SwiftUI

struct UserInfoView: View {
    @State private var code: String = ""
    var userInfo: UserInfo
    var onCodeSubmit: (String) async -> Void
    
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
        case .requestCode(let username, let image):
            HStack {
                Text("\(username) ")
                    .frame(alignment: .leading)
                Image(image, scale: 1.0, label: Text("code"))
                TextField("Code", text: $code)
                Button {
                    Task {
                        await onCodeSubmit(code)
                    }
                } label: {
                    Text("Submit")
                }
            }
        }
    }
}

#Preview {
    List {
        UserInfoView(userInfo: .logined(username: "demouser", paid: .paid), onCodeSubmit: { _ in })
        UserInfoView(userInfo: .logined(username: "demouser", paid: .unpaid), onCodeSubmit: { _ in })
        UserInfoView(userInfo: .logined(username: "demouser", paid: .paid), onCodeSubmit: { _ in })
    }
}

import WebShell

enum UserInfo: Equatable, Sendable {
    case requestCode(username: String, verifyCode: CGImage)
    case logined(username: String, paid: PaidUser)
    case unlogin(username: String)
}
