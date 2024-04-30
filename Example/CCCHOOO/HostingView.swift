//
//  HostingView.swift
//  WebShellExsample
//
//  Created by john on 2023/9/7.
//  Copyright © 2023 ascp. All rights reserved.
//

import AppKit
import SwiftUI

class HostingViewController: NSHostingController<ContentView> {
    override init?(coder: NSCoder, rootView: ContentView) {
        super.init(coder: coder, rootView: ContentView())
    }
    
    @MainActor required dynamic init?(coder: NSCoder) {
        super.init(coder: coder, rootView: ContentView())
    }
}
