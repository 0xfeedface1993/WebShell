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
}

func test116Loggin() {
    Task {
        do {
            try await _test116Login()
        } catch {
            print("[116] login failed! \(error)")
        }
    }
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
                        .join(LoginVerifyCode(username: ProcessInfo.processInfo.environment["username_116"] ?? "",
                                              password: ProcessInfo.processInfo.environment["pwd_116"] ?? "",
                                              configures: configuration, key: key))
                        .if(exists: .formhash)
                )
                .retry(3)
                .maybe({ value, task in
                    await !v2Exists(value)
                })
        )
}

func _test116Login() async throws {
    let key = SessionKey.host("116")
    let configuration = AsyncURLSessionConfiguration.shared
    
    let context = try await build116LoginCommands(configuration, key: key)
        .execute(for: "https://www.116pan.com/viewfile.php?file_id=527832")
    
    let formhash = try await context.string(.formhash)
    let code = try await context.string(.code)
    print("found formhash \(formhash), code \(code)")
    
    guard await v2Exists(context) else {
        throw TestError.nov2Cookie
    }
    
    print("v2 cookies updated.")
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

func _test116Logout() async throws {
    let keyStore = KeyStore()
    let configuration = AsyncURLSessionConfiguration.shared
    keyStore.assign("https://www.116pan.com/viewfile.php?file_id=527832", forKey: .fileidURL)
    keyStore.assign(configuration, forKey: .configures)
    
    let _ = try await Logout(configuration)
        .execute(for: keyStore)
    
    guard await !v2Exists(keyStore) else {
        throw TestError.v2CookieNotDeleted
    }
    
    print("v2 cookies deleted.")
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
