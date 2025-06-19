//
//  ContentView.swift
//  WebShellExsample
//
//  Created by john on 2023/9/6.
//  Copyright © 2023 ascp. All rights reserved.
//

import SwiftUI
import WebShell
import Durex
import AsyncAlgorithms

struct ContentView: View {
    @State var list = [DemoTaskObject]()
    let userInput = AsyncChannel<String>()
    let completion = AsyncChannel<(CGImage, String)>()
    @State private var textInput = ""
    
    var body: some View {
         table
//        UnitTestActionsView()
    }
    
    @ViewBuilder
    var table: some View {
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
        VStack {
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
            
            TextField("Code", text: $textInput)
        }
        .onChange(of: textInput, { oldValue, newValue in
            if newValue.count == 4 {
                Task {
                    await userInput.send(newValue)
                    textInput = ""
                }
            }
        })
        .task {
            list = [
                .init(
                    RedirectEnablePage(.shared, key: .host("a"))
                        .join(DownPage(.default))
                        .join(PHPLinks(.shared, key: .host("a")))
                        .join(Saver(.override, configures: .shared, tag: .string("a"), key: .host("a"))), tag: "a"
                )
                .title("迅牛盘-free")
                .url("http://www.xunniufxp.com/file-4182005.html"),
//                .init(
//                    RedirectFollowPage(.shared, key: .host("k"))
//                        .join(EraseOutValue(to: .fileidURL))
//                        .join(ExternalValueReader(AsyncURLSessionConfiguration.shared, forKey: .configures))
//                        .join(
//                            FileIDReader(finder: FileIDMatch.default)
//                                .or(FileIDInDomReader(FileIDMatch.addRef))
//                        )
//                        .join(
//                            LoginPage([:])
//                                .join(URLRequestPageReader(.output, configures: .shared, key: .host("k")))
//                                .join(
//                                    FindStringInFile(.htmlFile, forKey: .formhash, finder: .formhash)
//                                        .or(FindStringInFile(.htmlFile, forKey: .output, finder: .logined))
//                                )
//                                .join(
//                                    CodeImageCustomPathRequest("includes/imgcode.inc.php?verycode_type=2", configures: .shared, key: .host("k"))
//                                        .join(CodeImagePrediction(.shared, key: .host("k"), reader: codeReader(for: "k")))
//                                        .join(LoginVerifyCode(username: ProcessInfo.processInfo.environment["username_xn"] ?? "",
//                                                              password: ProcessInfo.processInfo.environment["pwd_xn"] ?? "",
//                                                              configures: .shared, key: .host("k")))
//                                        .if(exists: .formhash)
//                                )
//                                .retry(3)
//                                .maybe({ value, task in
//                                    !v2Exists(value)
//                                })
//                        )
//                        .join(AjaxFileListPageRequest("load_down_addr1"))
//                        .join(DowloadsListWithSignFileIDReader(.shared, key: .host("k")))
//                        .join(FileDefaultSaver(.override, configures: .shared, tag: .string("k"), key: .host("k"))), tag: "k"
//                )
//                .title("迅牛盘-vip")
//                .url("http://www.xunniufxp.com/file-4182005.html"),
//                .init(
//                    RedirectEnablePage(.shared, key: "b")
//                        .join(ActionDownPage())
//                        .join(PHPLinks(.shared, key: "b"))
//                        .join(Saver(.override, configures: .shared, key: "b")), tag: "b"
//                )
//                .title("XY盘")
//                .url("http://www.xingyaoclouds.com/fs/2nyqunuubbegazo"),
//                .init(
//                    RedirectEnablePage(.shared, key: "b")
//                        .join(AppendDownPath())
//                        .join(FileIDStringInDomSearchGroup(.loadDownAddr1, configures: .shared, key: "c"))
//                        .join(GeneralLinks(.shared, key: "c"))
//                        .join(Saver(.override, configures: .shared, key: "c")), tag: "c"
//                )
//                .title("ROSE盘-free")
//                .url("https://rosefile.net/6emc775g2p/s_MTGBHJKL.rar.html"),
//                .init(
//                    RedirectFollowPage(.shared, key: "j")
//                        .join(EraseOutValue(to: .fileidURL))
//                        .join(LoginPage(["action": "login", "job": "deny_share_login"]))
//                        .join(
//                            URLRequestPageReader(.output, configures: .shared, key: "j")
//                                .join(
//                                    FindStringInFile(.htmlFile, forKey: .formhash, finder: .formhash)
//                                        .or(FindStringInFile(.htmlFile, forKey: .output, finder: .logined))
//                                )
//                                .join(
//                                    LoginNoCode(username: ProcessInfo.processInfo.environment["username_rose"] ?? "",
//                                                password: ProcessInfo.processInfo.environment["pwd_rose"] ?? "",
//                                                configures: .shared, key: "j")
//                                    .if(exists: .formhash)
//                                )
//                        )
//                        .join(URLPageReader(.fileidURL, configures: .shared, key: "j"))
//                        .join(
//                            FileIDInDomReader(FileIDMatch.addRef)
//                                .or(FileIDInDomReader(FileIDMatch.addCoun))
//                        )
//                        .join(AjaxFileListPageRequest("check_recaptcha"))
//                        .join(DowloadsListWithSignFileIDReader(.shared, key: "j"))
//                        .join(HostDifferFilter())
//                        .join(FileDefaultSaver(.override, configures: .shared, key: "j")), tag: "j"
//                )
//                .title("ROSE盘-vip")
//                .url("https://rosefile.net/6emc775g2p/s_MTGBHJKL.rar.html"),
//                .init(
//                    HTTPString(.shared, key: "d")
//                        .join(RedirectEnablePage(.shared, key: "d"))
//                        .join(FileListURLRequestInPageGenerator(.downProcess4, action: "load_down_addr5", configures: .shared))
//                        .join(PHPLinks(.shared, key: "d"))
//                        .join(Saver(.override, configures: .shared, key: "d")), tag: "d"
//                )
//                .title("RARP盘")
//                .url("www.rarp.cc/fs/2494xuqmbg7wgha"),
//                .init(
//                    RedirectEnablePage(.shared, key: "e")
//                        .join(DownPage(.default))
//                        .join(PHPLinks(.shared, key: "e"))
//                        .join(Saver(.override, configures: .shared, key: "e")), tag: "e"
//                )
//                .title("雪球盘-free")
//                .url("http://www.xueqiupan.com/file-761588.html"),
//                .init(
//                    RedirectFollowPage(.shared, key: "l")
//                        .join(EraseOutValue(to: .fileidURL))
//                        .join(
//                            FileIDReader(finder: FileIDMatch.default)
//                                .or(FileIDInDomReader(FileIDMatch.addRef))
//                        )
//                        .join(ExternalValueReader(AsyncURLSessionConfiguration.shared, forKey: .configures))
//                        .join(
//                            LoginPage([:])
//                                .join(URLRequestPageReader(.output, configures: .shared, key: "l"))
//                                .join(
//                                    FindStringInFile(.htmlFile, forKey: .formhash, finder: .formhash)
//                                        .or(FindStringInFile(.htmlFile, forKey: .output, finder: .logined))
//                                )
//                                .join(
//                                    CodeImageCustomPathRequest("includes/imgcode.inc.php?verycode_type=2", configures: .shared, key: "l")
//                                        .join(CodeImagePrediction(.shared, key: "l", reader: codeReader(for: "l")))
//                                        .join(LoginVerifyCode(username: ProcessInfo.processInfo.environment["username_xq"] ?? "",
//                                                              password: ProcessInfo.processInfo.environment["pwd_xq"] ?? "",
//                                                              configures: .shared, key: "l"))
//                                        .if(exists: .formhash)
//                                )
//                                .retry(3)
//                                .maybe({ value, task in
//                                    !v2Exists(value)
//                                })
//                        )
//                        .join(AjaxFileListPageRequest("load_down_addr1"))
//                        .join(DowloadsListWithSignFileIDReader(.shared, key: "l"))
//                        .join(FileDefaultSaver(.override, configures: .shared, key: "l"))
//                    , tag: "l"
//                )
//                .title("雪球盘-vip")
//                .url("http://www.xueqiupan.com/file-761588.html"),
//                .init(
//                    RedirectEnablePage(.shared, key: "f")
//                        .join(FileListURLRequestGenerator(.default, action: "load_down_addr1"))
//                        .join(CDLinks(.shared, key: "f"))
//                        .join(Saver(.override, configures: .shared, key: "f")), tag: "f"
//                )
//                .title("exp盘")
//                .url("http://www.expfile.com/file-1622046.html"),
//                .init(
//                    RedirectFollowPage(.shared, key: "g")
//                        .join(EraseOutValue(to: .fileidURL))
//                        .join(
//                            FileIDReader(finder: FileIDMatch.default)
//                                .or(FileIDInDomReader(FileIDMatch.addRef))
//                        )
//                        .join(ExternalValueReader(AsyncURLSessionConfiguration.shared, forKey: .configures))
//                        .join(
//                            LoginPage([:])
//                                .join(URLRequestPageReader(.output, configures: .shared, key: "g"))
//                                .join(
//                                    FindStringInFile(.htmlFile, forKey: .formhash, finder: .formhash)
//                                        .or(FindStringInFile(.htmlFile, forKey: .output, finder: .logined))
//                                )
//                                .join(
//                                    CodeImageCustomPathRequest("includes/imgcode.inc.php?verycode_type=2", configures: .shared, key: "g")
//                                        .join(CodeImagePrediction(.shared, key: "g", reader: codeReader(for: "g")))
//                                        .join(LoginVerifyCode(username: ProcessInfo.processInfo.environment["username_567"] ?? "",
//                                                              password: ProcessInfo.processInfo.environment["pwd_567"] ?? "",
//                                                              configures: .shared, key: "g"))
//                                        .if(exists: .formhash)
//                                )
//                                .retry(3)
//                                .maybe({ value, task in
//                                    !v2Exists(value)
//                                })
//                        )
//                        .join(SignInDownPageRequest())
//                        .join(SignInDownPageReader(.shared, key: "g"))
//                        .join(DowloadsListWithSignFileIDRequest(action: "load_down_addr10"))
//                        .join(DowloadsListWithSignFileIDReader(.shared, key: "g"))
//                        .join(FileDefaultSaver(.override, configures: .shared, key: "g"))
//                    , tag: "g"
//                )
//                .title("567盘-vip")
//                .url("https://www.567yun.cn/file-2283887.html"),
//                .init(
//                    RedirectEnablePage(.shared, key: "i")
//                        .join(SignFileListURLRequestGenerator(.default, action: "load_down_addr10", configures: .shared))
//                        .join(SignLinks(.shared, key: "i"))
//                        .join(Saver(.override, configures: .shared, key: "i")), tag: "i"
//                )
//                .title("567盘-free")
//                .url("https://www.567yun.cn/file-2286747.html"),
//                .init(
//                    RedirectEnablePage(.shared, key: "h")
//                        .join(TowerGroup("load_down_addr2", configures: .shared, key: "h"))
//                        .join(PHPLinks(.shared, key: "h"))
//                        .join(Saver(.override, configures: .shared, key: "h")), tag: "h"
//                )
//                .title("爱优盘-free")
//                .url("https://www.iycdn.com/file-213019.html"),
//                .init(
////                    RedirectEnablePage(.shared, key: "h")
////                        .join(TowerGroup("load_down_addr2", configures: .shared, key: "h"))
////                        .join(PHPLinks(.shared, key: "h"))
////                        .join(Saver(.override, configures: .shared, key: "h")), tag: "h"
//                    RedirectFollowPage(.shared, key: "m")
//                        .join(EraseOutValue(to: .fileidURL))
//                        .join(
//                            FileIDReader(finder: FileIDMatch.default)
//                                .or(FileIDInDomReader(FileIDMatch.addRef))
//                        )
//                        .join(ExternalValueReader(AsyncURLSessionConfiguration.shared, forKey: .configures))
//                        .join(
//                            LoginPage([:])
//                                .join(URLRequestPageReader(.output, configures: .shared, key: "m"))
//                                .join(
//                                    FindStringInFile(.htmlFile, forKey: .formhash, finder: .formhash)
//                                        .or(FindStringInFile(.htmlFile, forKey: .output, finder: .logined))
//                                )
//                                .join(
//                                    CodeImageCustomPathRequest("includes/imgcode.inc.php?verycode_type=2", configures: .shared, key: "m")
//                                        .join(CodeImagePrediction(.shared, key: "m", reader: codeReader(for: "m")))
//                                        .join(LoginVerifyCode(username: ProcessInfo.processInfo.environment["username_ay"] ?? "",
//                                                              password: ProcessInfo.processInfo.environment["pwd_ay"] ?? "",
//                                                              configures: .shared, key: "m"))
//                                        .if(exists: .formhash)
//                                )
//                                .retry(3)
//                                .maybe({ value, task in
//                                    !v2Exists(value)
//                                })
//                        )
//                        .join(AjaxFileListPageRequest("load_down_addr2"))
//                        .join(
//                            URLRequestPageReader(.output, configures: .shared, key: "m")
//                                .join(FindStringsInFile(.htmlFile, forKey: .output, finder: .href))
//                                .join(
//                                    DownloadFileRequests(builder: SignPHPFileDownload())
//                                        .sort(.reverse)
//                                )
//                        )
//                        .join(FileDefaultSaver(.override, configures: .shared, key: "m"))
//                    , tag: "m"
//                )
//                .title("爱优盘-vip")
//                .url("https://www.iycdn.com/file-213019.html"),
                    .init(
//                        build116LoginCommands(.shared, key: .host("116"))
                        RedirectFollowPage(.shared, key: .host("116"))
                            .join(EraseOutValue(to: .fileidURL))
                            .join(
                                FileIDReader(finder: FileIDMatch.inQueryfileID)
                            )
                            .join(ExternalValueReader(AsyncURLSessionConfiguration.shared, forKey: .configures))
                            .join(
                                CodeImageRequest(.shared, path: .imageCodePHP, key: .host("116"))
                            )
                            .join(
                                CodeImagePrediction(.shared, key: .host("116"), reader: UserImageCodeReader(tag: "116", userInput: userInput, completion: completion))
                            )
                            .join(AjaxFileListPageRequest(.checkCode))
                            .join(
                                DowloadsListWithSignFileIDReader(.shared, builder: File116Download(), finder: .httpHref, key: .host("116"))
                            )
                            .join(
                                FileDefaultSaver(.override, configures: .shared, tag: .string("116"), key: .host("116"))
                            ),
                        tag: "116"
                    )
                    .title("116pan-free")
                    .url("https://www.116pan.com/viewfile.php?file_id=527832"),
                    .init(
                        RedirectFollowPage(.shared, key: .host("n"))
                            .join(EraseOutValue(to: .fileidURL))
                            .join(
                                FileIDReader(finder: FileIDMatch.default)
                                    .or(FileIDInDomReader(FileIDMatch.addRef))
                            )
                            .join(ExternalValueReader(AsyncURLSessionConfiguration.shared, forKey: .configures))
                            .join(
                                LoginPage(["action": "login"])
                                    .join(URLRequestPageReader(.output, configures: .shared, key: .host("n")))
                                    .join(
                                        FindStringInFile(.htmlFile, forKey: .formhash, finder: .formhash)
                                            .or(FindStringInFile(.htmlFile, forKey: .output, finder: .logined))
                                    )
                                    .join(
                                        CodeImageCustomPathRequest("includes/imgcode.inc.php?verycode_type=2", configures: .shared, key: .host("n"))
                                            .join(CodeImagePrediction(.shared, key: .host("n"), reader: codeReader(for: "n")))
                                            .join(LoginVerifyCode(username: ProcessInfo.processInfo.environment["username_116"] ?? "",
                                                                  password: ProcessInfo.processInfo.environment["pwd_116"] ?? "",
                                                                  configures: .shared, key: .host("n")))
                                            .if(exists: .formhash)
                                    )
                                    .retry(3)
                                    .maybe({ value, task in
                                        await !v2Exists(value)
                                    })
                            )
                            .join(AjaxFileListPageRequest(.checkCode))
                            .join(
                                DowloadsListWithSignFileIDReader(.shared, builder: File116Download(), finder: .href, key: .host("116"))
                            )
                            .join(FileDefaultSaver(.override, configures: .shared, tag: .string("116"), key: .host("116")))
                        , tag: "n"
                    )
                    .title("116pan-vip")
                    .url("https://www.116pan.com/viewfile.php?file_id=527832"),
            ]
            
            Task {
                for await (image, tag) in self.completion {
                    let object = list.first(where: { $0.tag == tag })
                    object?.imageCode = image
                    object?.objectWillChange.send()
                }
            }
        }
        .frame(minWidth: 500, minHeight: 200)
    }
    
    func codeReader(for tag: String) -> ImageCodeReader {
        ImageCodeReader(tag: tag, completion: { image, tag in
            Task { @MainActor in
                let object = list.first(where: { $0.tag == tag })
                object?.imageCode = image
                object?.objectWillChange.send()
            }
        })
    }
    
    func manualCodeReader(for tag: String) -> ImageCodeReader {
        ImageCodeReader(tag: tag, completion: { image, tag in
            Task { @MainActor in
                let object = list.first(where: { $0.tag == tag })
                object?.imageCode = image
                object?.objectWillChange.send()
            }
        })
    }
    
    func v2Exists(_ store: KeyStore) async -> Bool {
        do {
            return try await store.configures(.configures)
                .defaultSession
                .cookies()
                .contains(where: {
                    $0.name == "phpdisk_zcore_v2_info"
                })
        } catch {
            return false
        }
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
