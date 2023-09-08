//
//  DemoListItemView.swift
//  WebShellExsample
//
//  Created by john on 2023/9/6.
//  Copyright © 2023 ascp. All rights reserved.
//

import SwiftUI
import WebShell

struct DemoListItemView: View {
    @ObservedObject var object: DemoTaskObject
    
    var body: some View {
//        VStack {
//            HStack {
//                Text(object.url)
//                    .font(.body)
//                    .multilineTextAlignment(.leading)
//
//                Spacer()
//
//                if let error = object.error {
//                    Text(error)
//                        .bold()
//                        .foregroundColor(.red.opacity(0.6))
//                }
//
//                if object.progress == 1 {
//                    Text("下载完成")
//                        .bold()
//                        .foregroundColor(.green.opacity(0.6))
//                }   else if object.progress > 0   {
//                    Text("\(object.progress.formatted(.percent))")
//                }
//            }
//
//            if object.progress > 0 {
//                ProgressView(value: object.progress)
//                    .progressViewStyle(.linear)
//                    .foregroundColor(.accentColor)
//            }
//        }
//        .padding(.all, 8)
        Button("下载") {
            Task {
                await object.start()
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(object.loading)
    }
}

struct DemoListItemView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            StatefulObservblePreviewWrapper(task({ _ in
                
            })) { object in
                DemoListItemView(object: object)
            }
            
            StatefulObservblePreviewWrapper(task({ object in
                object.progress = 1
            })) { object in
                DemoListItemView(object: object)
            }
            
            StatefulObservblePreviewWrapper(task({ object in
                object.error = "网络中断"
            })) { object in
                DemoListItemView(object: object)
            }
        }
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
