//
//  UnitTestActionsView.swift
//  WebShellExsample
//
//  Created by york on 2025/6/19.
//  Copyright © 2025 ascp. All rights reserved.
//

import SwiftUI

struct UnitTestActionsView: View {
    var body: some View {
        List {
            Button {
                test116Loggin()
            } label: {
                Text("Login")
            }
            .listRowSeparator(.hidden)

            Button("logout") {
                test116Logout()
            }
            .listRowSeparator(.hidden)
        }
        
    }
}

#Preview {
    UnitTestActionsView()
}
