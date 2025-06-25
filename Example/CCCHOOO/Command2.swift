//
//  Koolaa.swift
//  WebShellExsample
//
//  Created by york on 2025/6/24.
//  Copyright © 2025 ascp. All rights reserved.
//

import Foundation
import Durex
import WebShell

func buildKoolaaVipLoginCommands(_ configuration: AsyncURLSessionConfiguration, key: SessionKey) -> AnyDirtyware<String, KeyStore> {
    ValueReader(.fileidURL)
        .join(
            LoginPostForm(
                username: ProcessInfo.processInfo.environment["username_koolaa_vip"] ?? "",
                password: ProcessInfo.processInfo.environment["pwd_koolaa_vip"] ?? "",
                configures: configuration,
                key: key
            )
            .maybe({ keyStore, form in
                do {
                    let user: PaidUser = try await Paid(
                        configures: keyStore.configures(.configures),
                        key: key,
                        catcher: PaidUserString(finder: .paidUser, key: key)
                    ).execute(for: keyStore).value(forKey: .paid) ?? .unpaid
                    return user == .unpaid
                } catch {
                    return true
                }
            })
        )
        .join(ExternalValueReader(configuration, forKey: .configures))
        .join(ExternalValueReader(key, forKey: .sessionKey))
}
