//
//  DummyTextView.swift
//  WebShellExsample
//
//  Created by john on 2023/9/7.
//  Copyright © 2023 ascp. All rights reserved.
//

import SwiftUI
import WebShell

struct BindingTextView: View {
    @Binding var text: String
    
    var body: some View {
        Text(text)
    }
}

struct DummyTextView<Object: ObservableObject>: View {
    @ObservedObject var object: Object
    let keypath: KeyPath<ObservedObject<Object>.Wrapper, Binding<String>>
//    @Binding var text: String
    
    var body: some View {
        BindingTextView(text: $object[keyPath: keypath])
    }
}

struct DummyTextView_Previews: PreviewProvider {
    static var previews: some View {
        StatefulObservblePreviewWrapper(task({ _ in

        })) { object in
            DummyTextView(object: object, keypath: \.title)
        }
//        StatefulPreviewWrapper("test") { binding in
//            DummyTextView(text: binding)
//        }
    }
    
    static func task(_ builder: (DemoTaskObject) -> Void) -> DemoTaskObject {
        let task = DemoTaskObject(
            RedirectEnablePage(.shared)
                .join(DownPage(.default))
                .join(PHPLinks(.shared))
                .join(Saver(.override, configures: .shared)), tag: "default"
        )
        task.url = "https://test.com/download/sss.zip"
        task.progress = 0.522
        task.title = "test"
        builder(task)
        return task
    }
}
