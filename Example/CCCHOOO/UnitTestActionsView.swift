//
//  UnitTestActionsView.swift
//  WebShellExsample
//
//  Created by york on 2025/6/19.
//  Copyright © 2025 ascp. All rights reserved.
//

import SwiftUI
import AsyncAlgorithms

struct UnitTestActionsView: View {
    @State private var pan116UserInfo = UserInfo.unlogin(username: ProcessInfo.processInfo.environment["username_116_free"]!)
    @State private var loading = false
    
    private let pan116UserInput = AsyncChannel<String>()
    private let pan116Completion = AsyncChannel<(CGImage, String)>()
    
    var body: some View {
        List {
            HStack {
                UserInfoView(userInfo: pan116UserInfo, onCodeSubmit: { code in
                    await pan116UserInput.send(code)
                })
                
                Button {
                    Task {
                        loading = true
                        pan116UserInfo = await test116FreeLogin(UserImageCodeReader(tag: "116", userInput: pan116UserInput, completion: pan116Completion))
                        loading = false
                    }
                } label: {
                    Text("Login")
                }
                .disabled(loading)
                
                Button("logout") {
                    Task {
                        loading = true
                        pan116UserInfo = await test116FreeLogout(pan116UserInfo)
                        loading = false
                    }
                }
                .disabled(loading)
            }
            .listRowSeparator(.hidden)
        }
        .task {
            for await (image, tag) in pan116Completion {
                switch pan116UserInfo {
                case .requestCode(let username, let verifyCode):
                    pan116UserInfo = .requestCode(username: username, verifyCode: image)
                case .logined(let username, let paid):
                    pan116UserInfo = .requestCode(username: username, verifyCode: image)
                case .unlogin(let username):
                    pan116UserInfo = .requestCode(username: username, verifyCode: image)
                }
            }
        }
    }
}

#Preview {
    UnitTestActionsView()
}
