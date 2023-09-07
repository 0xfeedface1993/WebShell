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
                .url("http://www.xunniufxp.com/file-4182005.html"),
                .init(
                    AsyncRedirectEnablePage(.shared, key: "b")
                        .join(AsyncActionDownPage())
                        .join(AsyncPHPLinks(.shared, key: "b"))
                        .join(AsyncSaver(.override, configures: .shared, key: "b")), tag: "b"
                )
                .title("XY盘")
                .url("http://www.xingyaoclouds.com/fs/2nyqunuubbegazo"),
                .init(
                    AsyncRedirectEnablePage(.shared, key: "b")
                        .join(AsyncAppendDownPath())
                        .join(AsyncFileIDStringInDomSearchGroup(.loadDownAddr1, configures: .shared, key: "c"))
                        .join(AsyncGeneralLinks(.shared, key: "c"))
                        .join(AsyncSaver(.override, configures: .shared, key: "c")), tag: "c"
                )
                .title("ROSE盘")
                .url("https://rosefile.net/6emc775g2p/s_MTGBHJKL.rar.html"),
                .init(
                    AsyncHTTPString(.shared, key: "d")
                        .join(AsyncRedirectEnablePage(.shared, key: "d"))
                        .join(AsyncFileListURLRequestInPageGenerator(.downProcess4, action: "load_down_addr5", configures: .shared))
                        .join(AsyncPHPLinks(.shared, key: "d"))
                        .join(AsyncSaver(.override, configures: .shared, key: "d")), tag: "d"
                )
                .title("RARP盘")
                .url("www.rarp.cc/fs/2494xuqmbg7wgha"),
                .init(
                    AsyncRedirectEnablePage(.shared, key: "e")
                        .join(AsyncDownPage(.default))
                        .join(AsyncPHPLinks(.shared, key: "e"))
                        .join(AsyncSaver(.override, configures: .shared, key: "e")), tag: "e"
                )
                .title("雪球盘")
                .url("http://www.xueqiupan.com/file-761588.html"),
                .init(
                    AsyncRedirectEnablePage(.shared, key: "f")
                        .join(AsyncFileListURLRequestGenerator(.default, action: "load_down_addr1"))
                        .join(AsyncCDLinks(.shared, key: "f"))
                        .join(AsyncSaver(.override, configures: .shared, key: "f")), tag: "f"
                )
                .title("exp盘")
                .url("http://www.expfile.com/file-1622046.html"),
                .init(
                    AsyncRedirectEnablePage(.shared, key: "g")
                        .join(AsyncSignFileListURLRequestGenerator(.default, action: "load_down_addr10", configures: .shared))
                        .join(AsyncSignLinks(.shared, key: "g"))
                        .join(AsyncSaver(.override, configures: .shared, key: "g")), tag: "g"
                )
                .title("567盘")
                .url("https://www.567yun.cn/file-2293462.html"),
                .init(
                    AsyncRedirectEnablePage(.shared, key: "h")
                        .join(AsyncTowerGroup("load_down_addr2", configures: .shared, key: "h"))
                        .join(AsyncPHPLinks(.shared, key: "h"))
                        .join(AsyncSaver(.override, configures: .shared, key: "h")), tag: "h"
                )
                .title("IY盘")
                .url("https://www.iycdn.com/file-213019.html"),
            ]
        }
        .frame(minWidth: 500, minHeight: 200)
    }
}

//TowerGroup("load_down_addr2", key: bundle.sessionKey)
//    .join(PHPLinks(bundle.sessionKey))
//    .join(BridgeSaver(bundle, policy: .normal, tag: Int(tagable.tagValue())))
//    .publisher(for: inputValue)

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
