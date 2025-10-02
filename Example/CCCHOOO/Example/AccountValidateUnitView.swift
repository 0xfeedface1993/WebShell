//
//  AccountValidateUnitView.swift
//  WebShellExsample
//
//  Created by york on 2025/9/5.
//  Copyright © 2025 ascp. All rights reserved.
//

import SwiftUI

struct AccountValidateUnitView: View {
    @State private var code = ""
    
    var body: some View {
        HStack {
            Text("State")
            
            VStack(alignment: .leading) {
                Text("Account")
                Text("password")
            }
            
            Image(systemName: "phone")
            TextField("Code", text: $code)
            Button {
                
            } label: {
                Text("Submit Code")
            }
        }
    }
}

#Preview {
    AccountValidateUnitView()
        .padding()
}
