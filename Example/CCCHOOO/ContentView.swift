//
//  ContentView.swift
//  WebShellExsample
//
//  Created by john on 2023/9/6.
//  Copyright © 2023 ascp. All rights reserved.
//

import SwiftUI
import WebShell

struct ContentView: View {
    @State var list = [DemoTaskObject]()
    
    var body: some View {
        ScrollView {
            VStack {
                ForEach(list, id: \.url) { object in
                    Section(object.title) {
                        DemoListItemView(object: object)
                            .onTapGesture {
                                Task {
                                    await object.start()
                                }
                            }
                    }
                }
            }
        }
        .task {
            list = [
                .init(
                    AsyncRedirectEnablePage(.shared, key: "a")
                        .join(AsyncDownPage(.default))
                        .join(AsyncPHPLinks(.shared, key: "a"))
                        .join(AsyncSaver(.override, configures: .shared, key: "a")), tag: "a"
                )
                .title("迅牛盘")
                .url("http://www.xunniu-pan.com/file-4067902.html"),
                .init(
                    AsyncRedirectEnablePage(.shared, key: "b")
                        .join(AsyncActionDownPage())
                        .join(AsyncPHPLinks(.shared, key: "b"))
                        .join(AsyncSaver(.override, configures: .shared, key: "b")), tag: "b"
                )
                .title("XY盘")
                .url("http://www.xingyaoclouds.com/fs/2l66xn9ubrzzwba"),
            ]
        }
        .frame(minWidth: 500, minHeight: 200)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
