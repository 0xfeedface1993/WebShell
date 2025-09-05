//
//  File.swift
//  WebShell
//
//  Created by york on 2025/8/31.
//

import Foundation
import Durex

extension LoginXSRFVerifyCode {
    public struct LoginedResponse: Codable {
        public let component: String?
        public let props: Props
        public let url: String?
        public let version: String?
        public let encryptHistory: Bool?
        public let clearHistory: Bool?
    }

    public struct Props: Codable {
        let errors: [String: String]?
        let auth: Auth
        let flash: Flash?
        let user: User?
        let stats: Stats?
        let notices: [Notice]?
        let captchaError: String?
        public let file: File?
        
        enum CodingKeys: CodingKey {
            case errors
            case auth
            case flash
            case user
            case stats
            case notices
            case captchaError
            case file
        }
        
        public init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<LoginXSRFVerifyCode.Props.CodingKeys> = try decoder.container(keyedBy: LoginXSRFVerifyCode.Props.CodingKeys.self)
            self.errors = try? container.decodeIfPresent([String:String].self, forKey: LoginXSRFVerifyCode.Props.CodingKeys.errors)
            self.auth = try container.decode(LoginXSRFVerifyCode.Auth.self, forKey: LoginXSRFVerifyCode.Props.CodingKeys.auth)
            self.flash = try container.decodeIfPresent(LoginXSRFVerifyCode.Flash.self, forKey: LoginXSRFVerifyCode.Props.CodingKeys.flash)
            self.user = try container.decodeIfPresent(LoginXSRFVerifyCode.User.self, forKey: LoginXSRFVerifyCode.Props.CodingKeys.user)
            self.stats = try container.decodeIfPresent(LoginXSRFVerifyCode.Stats.self, forKey: LoginXSRFVerifyCode.Props.CodingKeys.stats)
            self.notices = try container.decodeIfPresent([LoginXSRFVerifyCode.Notice].self, forKey: LoginXSRFVerifyCode.Props.CodingKeys.notices)
            self.captchaError = try container.decodeIfPresent(String.self, forKey: LoginXSRFVerifyCode.Props.CodingKeys.captchaError)
            self.file = try container.decodeIfPresent(LoginXSRFVerifyCode.File.self, forKey: LoginXSRFVerifyCode.Props.CodingKeys.file)
        }
        
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: LoginXSRFVerifyCode.Props.CodingKeys.self)
            try container.encodeIfPresent(self.errors, forKey: LoginXSRFVerifyCode.Props.CodingKeys.errors)
            try container.encode(self.auth, forKey: LoginXSRFVerifyCode.Props.CodingKeys.auth)
            try container.encodeIfPresent(self.flash, forKey: LoginXSRFVerifyCode.Props.CodingKeys.flash)
            try container.encodeIfPresent(self.user, forKey: LoginXSRFVerifyCode.Props.CodingKeys.user)
            try container.encodeIfPresent(self.stats, forKey: LoginXSRFVerifyCode.Props.CodingKeys.stats)
            try container.encodeIfPresent(self.notices, forKey: LoginXSRFVerifyCode.Props.CodingKeys.notices)
            try container.encodeIfPresent(self.captchaError, forKey: LoginXSRFVerifyCode.Props.CodingKeys.captchaError)
            try container.encodeIfPresent(self.file, forKey: LoginXSRFVerifyCode.Props.CodingKeys.file)
        }
    }

    struct Auth: Codable {
        let user: SimpleUser?
    }

    public struct SimpleUser: Codable, Equatable, ContextValue {
        public let userid: Int
        public let username: String?
        public let is_activated: Bool
        public let is_vip: Bool
        public let vip_id: Int
        public let vip_end_time: Int?
        public let vip_end_time_formatted: String?
        public let vip_remaining_days: Int?
        public let avatar: String?
        
        public var valueDescription: String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            do {
                return try String(data: encoder.encode(self), encoding: .utf8) ?? "nil"
            } catch {
                return "\(self)"
            }
        }
    }

    struct Flash: Codable {
        let success: String?
        let error: String?
    }

    struct User: Codable {
        let userid: Int?
        let username: String?
        let email: String?
        let qq: String?
        let gid: Int?
        let is_activated: Bool?
        let is_locked: Bool?
        let last_login_time: Int?
        let last_login_ip: String?
        let reg_time: Int?
        let reg_ip: String?
        let credit: Int?
        let m_credit: Int?
        let dl_credit: Int?
        let dl_credit2: Int?
        let wealth: String?
        let rank: Int?
        let exp: Int?
        let accept_pm: Bool?
        let show_email: Bool?
        let user_file_types: String?
        let user_store_space: String?
        let user_rent_space: String?
        let down_flow_count: String?
        let view_flow_count: String?
        let flow_reset_time: Int?
        let max_flow_down: String?
        let max_flow_view: String?
        let space_name: String?
        let mydowns: Int?
        let dl_mydowns: Int?
        let income_account: String?
        let income_name: String?
        let income_type: String?
        let open_custom_stats: Bool?
        let stat_code: String?
        let check_custom_stats: Bool?
        let logo: String?
        let face: String?
        let mybg: String?
        let logo_url: String?
        let credit_rate: String?
        let mydowns_rate: String?
        let downline_income: String?
        let downline_income2: String?
        let curr_tpl: String?
        let used_space: String?
        let discount_rate: String?
        let plan_id: Int?
        let open_plan: Bool?
        let domain: String?
        let mod_subdomain: Int?
        let can_edit: Bool?
        let my_announce: String?
        let vip_id: Int?
        let vip_end_time: Int?
        let sign_time: Int?
        let plan_conv_time: Int?
        let fixed_plan: Bool?
        let cnzz_user: String?
        let mod_account: Bool?
        let dlink_info: String?
        let can_share_login: Bool?
        let real_name_auth: Bool?
        let idcard1: String?
        let idcard2: String?
        let idcard_endtime: Int?
        let idcard_status: Int?
        let idcard_reason: String?
        let idcard_num: String?
        let idcard_name: String?
        let daydowns_info: String?
        let earnings_priority: Int?
        let hide_stats: Int?
        let hide_time: Int?
        let hide_save_as: Int?
        let hide_username: Bool?
        let is_vip: Bool?
        let vip_remaining_days: Int?
        let vip_end_time_formatted: String?
        let last_login_time_formatted: String?
        let earnings_level: String?
        let total_storage: Int?
        let used_storage: Int?
        let download_quota: DownloadQuota?
    }

    struct DownloadQuota: Codable {
        let today_downloads: Int?
        let daily_limit: Int?
        let remaining: Int?
        let quota_text: String?
        let quota_class: String?
        let is_vip: Bool?
    }

    struct Stats: Codable {
        let yesterday_downloads: Int?
        let balance: Double?
        let yesterday_rebate: Int?
        let today_rebate: Int?
    }

    struct Notice: Codable {
        let id: Int?
        let title: String?
        let created_at: String?
    }
    
    public struct File: Codable {
//        "file": {
//                    "file_id": 600739,
//                    "file_name": "A12270",
//                    "file_extension": "zip",
//                    "file_size": 346006315,
//                    "file_time": 1752100479,
//                    "file_views": 333,
//                    "file_downs": 274,
//                    "username": "\u53fd\u53fd\u5495\u53fd\u53fd",
//                    "uploader_id": 1013,
//                    "vipfile": false,
//                    "server_oid": 13,
//                    "saveas_hidden": 0
//                }
        public let file_id: Int
    }
}

extension LoginXSRFVerifyCode {
    enum LoginState: Equatable {
        case invalidAccount
        case invalidPassword
        case invalidCaptcha
        case logined(SimpleUser)
        
        init(_ props: Props) {
            guard let user = props.auth.user else {
                if let errors = props.errors {
                    if let login = errors["login"], login == "密码错误" {
                        self = .invalidPassword
                    } else {
                        self = .invalidAccount
                    }
                    shellLogger.error("login failed error: \(errors)")
                } else if let captchaError = props.captchaError {
                    self = .invalidCaptcha
                    shellLogger.error("login captchaError: \(captchaError)")
                } else {
                    self = .invalidAccount
                    shellLogger.error("login unknown error!")
                }
                return
            }
            self = .logined(user)
        }
    }
}
