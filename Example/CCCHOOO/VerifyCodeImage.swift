//
//  VerifyCodeImage.swift
//  WebShellExsample
//
//  Created by john on 2023/9/12.
//  Copyright © 2023 ascp. All rights reserved.
//

import SwiftUI
import WebShell

struct VerifyCodeImage: View {
    @ObservedObject var object: DemoTaskObject
    
    var body: some View {
        if let image = object.imageCode {
            Image(image, scale: 1.0, label: Text("code"))
                .resizable()
                .frame(width: 200)
        }   else    {
            Text("-")
        }
    }
}

struct VerifyCodeImage_Previews: PreviewProvider {
    static var previews: some View {
        StatefulObservblePreviewWrapper(task({ _ in
            
        })) { object in
            VerifyCodeImage(object: object)
        }
    }
    
    static func task(_ builder: (DemoTaskObject) -> Void) -> DemoTaskObject {
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
}
