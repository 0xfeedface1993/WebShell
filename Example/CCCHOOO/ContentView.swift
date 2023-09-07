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
//        ScrollView {
//            VStack {
////                ForEach(list, id: \.url) { object in
////                    Section(object.title) {
////                        DemoListItemView(object: object)
////                            .onTapGesture {
////                                Task {
////                                    await object.start()
////                                }
////                            }
////                    }
////                }
//
//                Table(list) {
//                    TableColumn("网盘", value: \.title)
//                    TableColumn("下载地址", value: \.url)
//                    TableColumn("状态", value: \.state)
//                    TableColumn("下载进度", value: \.state)
//                    TableColumn("下载按钮") { row in
//                        Button("下载") {
//                            Task {
//                                await row.start()
//                            }
//                        }
//                    }
//                }
//            }
//        }
        Table(list) {
            TableColumn("网盘") { row in
                DummyTextView(object: row, keypath: \.title)
            }
            .width(min: 40)
            TableColumn("下载地址") { row in
                DummyTextView(object: row, keypath: \.url)
            }
            .width(min: 100)
            TableColumn("状态") { row in
                DummyTextView(object: row, keypath: \.state)
            }
            .width(min: 40)
            TableColumn("文件大小") { row in
                DummyTextView(object: row, keypath: \.fileSize)
            }
            .width(min: 40)
            TableColumn("下载进度") { row in
                DummyTextView(object: row, keypath: \.formatterProgress)
            }
            .width(min: 80)
            TableColumn("下载按钮") { row in
                DemoListItemView(object: row)
            }
            .width(min: 40)
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
