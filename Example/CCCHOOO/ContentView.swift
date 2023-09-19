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
//                DummyTextView(object: row, keypath: \.url)
                URLTextFieldView(object: row, keypath: \.url)
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
            TableColumn("验证码") { row in
                VerifyCodeImage(object: row)
            }
            .width(min: 40)
        }
        .task {
            list = [
                .init(
                    RedirectEnablePage(.shared, key: "a")
                        .join(DownPage(.default))
                        .join(PHPLinks(.shared, key: "a"))
                        .join(Saver(.override, configures: .shared, key: "a")), tag: "a"
                )
                .title("迅牛盘")
                .url("http://www.xunniufxp.com/file-4182005.html"),
                .init(
                    RedirectEnablePage(.shared, key: "b")
                        .join(ActionDownPage())
                        .join(PHPLinks(.shared, key: "b"))
                        .join(Saver(.override, configures: .shared, key: "b")), tag: "b"
                )
                .title("XY盘")
                .url("http://www.xingyaoclouds.com/fs/2nyqunuubbegazo"),
                .init(
                    RedirectEnablePage(.shared, key: "b")
                        .join(AppendDownPath())
                        .join(FileIDStringInDomSearchGroup(.loadDownAddr1, configures: .shared, key: "c"))
                        .join(GeneralLinks(.shared, key: "c"))
                        .join(Saver(.override, configures: .shared, key: "c")), tag: "c"
                )
                .title("ROSE盘-free")
                .url("https://rosefile.net/6emc775g2p/s_MTGBHJKL.rar.html"),
                .init(
                    RedirectFollowPage(.shared, key: "j")
                        .join(EraseOutValue(to: .fileidURL))
                        .join(LoginPage([:]))
                        .join(
                            LoginWithFormhashMaybeLogined(ProcessInfo.processInfo.environment["username_rose"] ?? "",
                                                          password: ProcessInfo.processInfo.environment["pwd_rose"] ?? "",
                                                          configures: .shared,
                                                          key: "j")
                        )
                        .join(URLPageReader(.fileidURL, configures: .shared, key: "j"))
                        .join(FileIDInDomReader(FileIDMatch.addRef))
                        .join(AjaxFileListPageRequest("load_down_addr1"))
                        .join(DowloadsListWithSignFileIDReader(.shared, key: "j"))
                        .join(FileDefaultSaver(.override, configures: .shared, key: "j")), tag: "j"
                )
                .title("ROSE盘-vip")
                .url("https://rosefile.net/6emc775g2p/s_MTGBHJKL.rar.html"),
                .init(
                    HTTPString(.shared, key: "d")
                        .join(RedirectEnablePage(.shared, key: "d"))
                        .join(FileListURLRequestInPageGenerator(.downProcess4, action: "load_down_addr5", configures: .shared))
                        .join(PHPLinks(.shared, key: "d"))
                        .join(Saver(.override, configures: .shared, key: "d")), tag: "d"
                )
                .title("RARP盘")
                .url("www.rarp.cc/fs/2494xuqmbg7wgha"),
                .init(
                    RedirectEnablePage(.shared, key: "e")
                        .join(DownPage(.default))
                        .join(PHPLinks(.shared, key: "e"))
                        .join(Saver(.override, configures: .shared, key: "e")), tag: "e"
                )
                .title("雪球盘")
                .url("http://www.xueqiupan.com/file-761588.html"),
                .init(
                    RedirectEnablePage(.shared, key: "f")
                        .join(FileListURLRequestGenerator(.default, action: "load_down_addr1"))
                        .join(CDLinks(.shared, key: "f"))
                        .join(Saver(.override, configures: .shared, key: "f")), tag: "f"
                )
                .title("exp盘")
                .url("http://www.expfile.com/file-1622046.html"),
                .init(
                    RedirectFollowPage(.shared, key: "g")
                        .join(EraseOutValue(to: .fileidURL))
                        .join(FileIDReader(finder: FileIDMatch.default))
                        .join(LoginByFormhashAndCode(ProcessInfo.processInfo.environment["username_567"] ?? "",
                                                     password: ProcessInfo.processInfo.environment["pwd_567"] ?? "",
                                                     configures: .shared,
                                                     key: "g", retry: 3,
                                                     reader: ImageCodeReader(tag: "g", completion: { image, tag in
                                                         Task { @MainActor in
                                                             let object = list.first(where: { $0.tag == tag })
                                                             object?.imageCode = image
                                                             object?.objectWillChange.send()
                                                         }
                                                     })))
                        .join(SignInDownPageRequest())
                        .join(SignInDownPageReader(.shared, key: "g"))
                        .join(DowloadsListWithSignFileIDRequest(action: "load_down_addr10"))
                        .join(DowloadsListWithSignFileIDReader(.shared, key: "g"))
                        .join(FileDefaultSaver(.override, configures: .shared, key: "g"))
                    , tag: "g"
                )
                .title("567盘")
                .url("https://www.567yun.cn/file-2283887.html"),
                .init(
                    RedirectEnablePage(.shared, key: "i")
                        .join(SignFileListURLRequestGenerator(.default, action: "load_down_addr10", configures: .shared))
                        .join(SignLinks(.shared, key: "i"))
                        .join(Saver(.override, configures: .shared, key: "i")), tag: "i"
                )
                .title("567盘-free")
                .url("https://www.567yun.cn/file-2286747.html"),
                .init(
                    RedirectEnablePage(.shared, key: "h")
                        .join(TowerGroup("load_down_addr2", configures: .shared, key: "h"))
                        .join(PHPLinks(.shared, key: "h"))
                        .join(Saver(.override, configures: .shared, key: "h")), tag: "h"
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
