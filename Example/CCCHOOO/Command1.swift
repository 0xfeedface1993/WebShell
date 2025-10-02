//
//  116.swift
//  WebShellExsample
//
//  Created by york on 2025/6/19.
//  Copyright © 2025 ascp. All rights reserved.
//

import Foundation
import Durex
import WebShell

enum TestError: Error {
    case v2CookieNotDeleted
    case nov2Cookie
    case noPaidInfo
    case notPaidUser
}

func test116Loggin() {
//    Task {
//        do {
//            try await _test116Login(<#UserImageCodeReader#>)
//        } catch {
//            print("[116] login failed! \(error)")
//        }
//    }
}

func build116LoginCommands(_ configuration: AsyncURLSessionConfiguration, key: SessionKey) -> AnyDirtyware<String, KeyStore> {
    RedirectFollowPage(configuration, key: key)
        .join(EraseOutValue(to: .fileidURL))
        .join(
            FileIDReader(finder: FileIDMatch.inQueryfileID)
        )
        .join(ExternalValueReader(configuration, forKey: .configures))
        .join(
            LoginPage(["action": "login"])
                .join(URLRequestPageReader(.output, configures: configuration, key: key))
                .join(
                    FindStringInFile(.htmlFile, forKey: .formhash, finder: .formhash)
                        .or(FindStringInFile(.htmlFile, forKey: .output, finder: .logined))
                )
                .join(
                    CodeImageCustomPathRequest("includes/imgcode.inc.php?verycode_type=2", configures: configuration, key: key)
                        .join(CodeImagePrediction(configuration, key: key, reader: codeReader(for: "116")))
                        .join(LoginVerifyCode(username: ProcessInfo.processInfo.environment["username_116_free"] ?? "",
                                              password: ProcessInfo.processInfo.environment["pwd_116_free"] ?? "",
                                              configures: configuration, key: key))
                        .if(exists: .formhash)
                )
                .retry(3)
                .maybe({ value, task in
                    await !v2Exists(value)
                })
                .join(
                    Paid(configures: configuration, key: key, catcher: FreeUserString(finder: .vipExpired, path: .mydisk, key: key))
                )
        )
}

func build116VipLoginCommands(_ configuration: AsyncURLSessionConfiguration, key: SessionKey) -> AnyDirtyware<String, KeyStore> {
    RedirectFollowPage(configuration, key: key)
        .join(EraseOutValue(to: .fileidURL))
        .join(
            FileIDReader(finder: FileIDMatch.inQueryfileID)
        )
        .join(ExternalValueReader(configuration, forKey: .configures))
        .join(
            LoginPage(["action": "login"])
                .join(URLRequestPageReader(.output, configures: configuration, key: key))
                .join(
                    FindStringInFile(.htmlFile, forKey: .formhash, finder: .formhash)
                        .or(FindStringInFile(.htmlFile, forKey: .output, finder: .logined))
                )
                .join(
                    CodeImageCustomPathRequest("includes/imgcode.inc.php?verycode_type=2", configures: configuration, key: key)
                        .join(CodeImagePrediction(configuration, key: key, reader: codeReader(for: "116")))
                        .join(LoginVerifyCode(username: ProcessInfo.processInfo.environment["username_116_vip"] ?? "",
                                              password: ProcessInfo.processInfo.environment["pwd_116_vip"] ?? "",
                                              configures: configuration, key: key))
                        .if(exists: .formhash)
                )
                .retry(3)
                .maybe({ value, task in
                    await !v2Exists(value)
                })
        )
}

func test116FreeLogin(_ coder: UserImageCodeReader) async -> UserInfo {
    let username = ProcessInfo.processInfo.environment["username_116_free"]!
    do {
        return try await _test116Login(coder)
    } catch let error as TestError {
        switch error {
        case .v2CookieNotDeleted:
            return .unlogin(username: username)
        case .nov2Cookie:
            return .unlogin(username: username)
        case .noPaidInfo:
            return .unlogin(username: username)
        case .notPaidUser:
            return .logined(username: username, paid: .unpaid)
        }
    } catch {
        return .unlogin(username: username)
    }
}

func _test116Login(_ coder: UserImageCodeReader) async throws -> UserInfo {
    let key = SessionKey.host("116")
    let configuration = AsyncURLSessionConfiguration.shared
    let context = try await build116LoginCommandsV2(configuration, key: key, coder: coder)
        .execute(for: "https://www.116pan.xyz/f/Ty0dEc")
    let urls = [
        "https://www.116pan.xyz/f/isoLjk",
        "https://www.116pan.xyz/f/RyXYOM",
        "https://www.116pan.xyz/f/Q14ULO"
    ]
    for url in urls {
        let _ =
        try? await JustValue()
            .join(CopyOutValue(.output, to: .fileidURL))
            .join(ExternalValueReader(configuration, forKey: .configures))
            .join(ExternalValueReader(key, forKey: .sessionKey))
            .join(XRCFDownload(codeReader: ImageCodeReader(tag: "116", completion: { _, _ in })))
            .execute(for: url)
    }
    
//    guard let user: LoginXSRFVerifyCode.SimpleUser = await context.value(forKey: .jsonUser) else {
//        throw TestError.nov2Cookie
//    }
//    
//    let paid: PaidUser? = await context.value(forKey: .paid)
//    guard let paid else {
//        throw TestError.noPaidInfo
//    }
//    
//    print("v2 cookies updated.")
    return .logined(username: ProcessInfo.processInfo.environment["username_116_vip"]!, paid: .paid)
}

func test116Loginv2() async throws -> UserInfo {
    let key = SessionKey.host("116")
    let configuration = AsyncURLSessionConfiguration.shared
    
//    let context = try await build116LoginCommandsV2(configuration, key: key, coder: UserImageCodeReader(tag: "116", userInput: <#T##AsyncChannel<String>#>, completion: <#T##AsyncChannel<(CGImage, String)>#>))
//        .execute(for: "https://www.116pan.xyz/f/N1eSOK")
    
//    guard await v2Exists(context) else {
//        throw TestError.nov2Cookie
//    }
//
//    let paid: PaidUser? = await context.value(forKey: .paid)
//    guard let paid else {
//        throw TestError.noPaidInfo
//    }
//
//    print("v2 cookies updated.")
//
//    return .logined(username: ProcessInfo.processInfo.environment["username_116_free"]!, paid: paid)
    return .unlogin(username: ProcessInfo.processInfo.environment["username_116_free"]!)
}


func test116Logout() {
    Task {
        do {
            try await _test116Logout()
        } catch {
            print("[116] logout failed! \(error)")
        }
    }
}

func test116FreeLogout(_ info: UserInfo) async -> UserInfo {
    switch info {
    case .logined(let username, let paid):
        do {
            try await _test116Logout()
            return .unlogin(username: username)
        } catch {
            print("[116] logout failed! \(error)")
            return info
        }
    case .unlogin(let username):
        return info
    case .requestCode(username: let username, verifyCode: let verifyCode):
        return info
    }    
}

func _test116Logout() async throws {
    let keyStore = KeyStore()
    let configuration = AsyncURLSessionConfiguration.shared
    keyStore.assign("https://www.116pan.xyz/f/7dquou", forKey: .fileidURL)
    keyStore.assign(configuration, forKey: .configures)
    keyStore.assign(SessionKey.host("116"), forKey: .sessionKey)
    
    let _ = try await Logout(configuration, option: .logout)
        .execute(for: keyStore)
    
    print("logout")
}

func testDownload() {
    Task {
        do {
            try await _testDownload()
        } catch {
            print("[116] download failed! \(error)")
        }
    }
}


func _testDownload() async throws {
    
}

private func codeReader(for tag: String) -> ImageCodeReader {
    ImageCodeReader(tag: tag, completion: { image, tag in
        print("[\(tag)] found image code")
    })
}

private func v2Exists(_ store: KeyStore) async -> Bool {
    do {
        return try await store.configures(.configures)
            .defaultSession
            .cookies()
            .contains(where: {
                $0.name == "phpdisk_zcore_v2_info" && !$0.value.contains("deleted")
            })
    } catch {
        return false
    }
}


func build116LoginCommandsV2<Coder: CodeReadable>(_ configuration: AsyncURLSessionConfiguration, key: SessionKey, coder: Coder) -> AnyDirtyware<String, KeyStore> {
    RedirectFollowPage(configuration, key: key)
        .join(EraseOutValue(to: .fileidURL))
        .join(ExtractCSXFCookie())
        .join(DataPartTransformer())
        .map { store in
            let json: LoginXSRFVerifyCode.LoginedResponse = try await decode(store)
            if let fileid = json.props.file?.file_id {
                store.assign("\(fileid)", forKey: .fileid)
            }
        }
        .join(ExternalValueReader(configuration, forKey: .configures))
        .join(
            URLRequestSinglePageBuilder(build: { store in
                try await LoginXSRFVerifyCode.PreRequest(store: store).make()
            })
            .join(URLRequestPageReader(.output, configures: configuration, key: key))
            .join(ExtractCSXFCookie())
            .join(
                CodeImageCustomPathRequest("captcha/20", configures: configuration, key: key)
                    .join(CodeImagePrediction(configuration, key: key, reader: coder))
                    .map({ store in
                        let code = try await store.string(.code)
                        guard code.count == 4 else {
                            throw ShellError.invalidCode(code)
                        }
                    })
                    .retry(10)
                    .join(LoginXSRFVerifyCode(
                        username: ProcessInfo.processInfo.environment["username_116_free"] ?? "",
                        password: ProcessInfo.processInfo.environment["pwd_116_free"] ?? "",
                        configures: configuration,
                        key: key
                    ))
                    .retry(3)
                    .maybe({ value, task in
                        guard let output: LoginXSRFVerifyCode.SimpleUser = await value.value(forKey: .jsonUser) else {
                            return true
                        }
                        logger.info("found logined info: \(output).")
                        return false
                    })
            )
//            .join(
//                PaidGuard(Paid(configures: configuration, key: key, catcher: XSRFPaidUser()))
//            )
        )
}

struct XRCFDownload<C: CodeReadable>: Dirtyware {
    typealias Input = KeyStore
    typealias Output = URL
    
    let codeReader: C
    
    func execute(for inputValue: KeyStore) async throws -> URL {
        let configures = try await inputValue.configures(.configures)
        let session = try await inputValue.sessionKey(.sessionKey)
        let fileURL = try await inputValue.string(.fileidURL)
        return try await RedirectFollowPage(configures, key: session)
            .join(ExtractCSXFCookie())
            .join(DataPartTransformer())
            .map { store in
                let json: LoginXSRFVerifyCode.LoginedResponse = try await decode(store)
                if let fileid = json.props.file?.file_id {
                    store.assign("\(fileid)", forKey: .fileid)
                }
            }
            .join(ExternalValueReader(fileURL, forKey: .fileidURL))
            .join(
                URLRequestSinglePageBuilder(build: { store in
                    try await GenerateDownloadRequest(store).builder()
                })
            )
            .join(URLRequestPageReader(.output, configures: configures, key: session))
            .join(ExtractCSXFCookie())
            .map { store in
                let json: XRCFDownloadInfo = try await decode(store)
                let request = try await URLRequestBuilder(url: json.download_url, method: .get, headers: nil, body: nil)
                    .add(.allCapAccept)
                    .add(.gzipAcceptEncoding)
                    .add(.customUserAgent)
                    .add(value: store.string(.fileidURL), forKey: .referer)
                    .add(.keepAliveConnection)
                store.assign([request], forKey: .output)
            }
            .erase(to: [URLRequestBuilder].self)
            .join(Saver(configures: configures, tag: .string("116"), key: session))
            .execute(for: fileURL)
    }
}
