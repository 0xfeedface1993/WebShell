//
//  URLTextFieldView.swift
//  WebShellExsample
//
//  Created by john on 2023/9/19.
//  Copyright © 2023 ascp. All rights reserved.
//

import SwiftUI
import WebShell

struct URLTextFieldView<Object: ObservableObject>: View {
    @ObservedObject var object: Object
    let keypath: KeyPath<ObservedObject<Object>.Wrapper, Binding<String>>
    
    var body: some View {
       TextField("url link", text: $object[keyPath: keypath])
    }
}

#Preview {
    StatefulObservblePreviewWrapper(task({ _ in

    })) { object in
        URLTextFieldView(object: object, keypath: \.url)
    }
}

fileprivate func task(_ builder: (DemoTaskObject) -> Void) -> DemoTaskObject {
    let task = DemoTaskObject(
        RedirectEnablePage(.shared)
            .join(DownPage(.default))
            .join(PHPLinks(.shared))
            .join(Saver(.override, configures: .shared, tag: .string("default"))), tag: "default"
    )
    task.url = "https://test.com/download/sss.zip"
    task.progress = 0.522
    task.title = "test"
    builder(task)
    return task
}
