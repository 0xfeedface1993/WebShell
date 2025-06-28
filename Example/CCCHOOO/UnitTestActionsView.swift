//
//  UnitTestActionsView.swift
//  WebShellExsample
//
//  Created by york on 2025/6/19.
//  Copyright © 2025 ascp. All rights reserved.
//

import SwiftUI

struct UnitTestActionsView: View {
    @State private var pan116UserInfo = UserInfo.unlogin(username: ProcessInfo.processInfo.environment["username_116_free"]!)
    @State private var loading = false
    
    var body: some View {
        List {
            HStack {
                UserInfoView(userInfo: pan116UserInfo)
                
                Button {
                    Task {
                        loading = true
                        pan116UserInfo = await test116FreeLogin()
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
    }
}

#Preview {
    UnitTestActionsView()
}
