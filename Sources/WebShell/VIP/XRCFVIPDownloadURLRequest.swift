//
//  File.swift
//  WebShell
//
//  Created by york on 2025/9/4.
//

import Foundation

public struct XRCFVIPDownloadURLRequest: Codable, Sendable {
    public let type: String
    public let click_pos: String
    public let screen: String
    public let ref: String
    
    public static let `default` = XRCFVIPDownloadURLRequest(
        type: "vip",
        click_pos: "690,689",
        screen: "1920x1080",
        ref: "download_vip"
    )
}

public struct XRCFDownloadInfo: Codable {
    public let download_url: String
    public let success: Bool
    public let is_repeated: Bool
}
