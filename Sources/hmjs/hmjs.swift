import Foundation
//import Playgrounds

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public func extractHMAccount(_ text: String) throws -> String {
    if #available(macOS 13.0, *) {
        let regex = Regex(/hca:\s?'([^']+)'/)
        guard let hca = try regex.firstMatch(in: text)?[1].substring else {
            return ""
        }
        return String(hca)
    } else {
        // Fallback on earlier versions
        let regex = try NSRegularExpression(pattern: "hca:\\s?'([^']+)'")
        let hca = regex
        return hca.matches(in: text, range: NSRange(location: 0, length: text.utf16.count))
            .map { regex.replacementString(for: $0, in: text, offset: 0, template: "$1") }
            .first ?? ""
    }
}

public func extractID(_ text: String) throws -> String {
    if #available(macOS 13.0, *) {
        let regex = Regex(/id:\s?"([^"]+)"/)
        guard let hca = try regex.firstMatch(in: text)?[1].substring else {
            return ""
        }
        return String(hca)
    } else {
        // Fallback on earlier versions
        let regex = try NSRegularExpression(pattern: "id:\\s?\"([^\"]+)\"")
        let hca = regex
        return hca.matches(in: text, range: NSRange(location: 0, length: text.utf16.count))
            .map { regex.replacementString(for: $0, in: text, offset: 0, template: "$1") }
            .first ?? ""
    }
}

public func extractDomains(_ text: String) throws -> [String] {
    if #available(macOS 13.0, *) {
        let regex = Regex(/dm:\s?\[(\.?"([^"]+)")*\]/)
        return text.matches(of: regex)
            .compactMap({ $0[1].substring })
            .map(String.init(_:))
    } else {
        // Fallback on earlier versions
        let regex = try NSRegularExpression(pattern: "dm:\\s?\\[(\\.?\"([^\"]+)\")*\\]")
        let hca = regex
        return hca.matches(in: text, range: NSRange(location: 0, length: text.utf16.count))
            .map { regex.replacementString(for: $0, in: text, offset: 0, template: "$2") }
    }
}

public func updateHmCookies(
    js: String,
    existingLvt: String?,
    existingLpvt: String?,
    nowSeconds: Int = Int(Date().timeIntervalSince1970),
    vdur: Int = 1800,
    maxEntries: Int = 4,
    windowSeconds: Int = 2_592_000,
    ageSeconds: Int = 31_536_000
) throws -> (lvt: String, lpvt: String, cookies: [HTTPCookie]) {
    let account = try extractHMAccount(js)
    let id = try extractID(js)
    let domains = try extractDomains(js)
    return updateHmCookies(siteId: id, existingLvt: existingLvt, existingLpvt: existingLpvt, nowSeconds: nowSeconds, vdur: vdur, maxEntries: maxEntries, windowSeconds: windowSeconds, ageSeconds: ageSeconds, domain: domains.first ?? "/")
}

/// 更新 Hm_lvt_ 和 Hm_lpvt_ 的逻辑
/// - Parameters:
///   - siteId: 站点 id（hm cookie id 部分）
///   - existingLvt: 现有的 Hm_lvt_<siteId> cookie 值（逗号分隔的秒级时间戳），若无则传 nil
///   - existingLpvt: 现有的 Hm_lpvt_<siteId> cookie 值（单个秒级时间戳），若无则传 nil
///   - nowSeconds: 当前时间（秒），默认使用 Date()
///   - vdur: 会话阈值（秒），若 now - lastPv > vdur 则把当前时间加入 lvt，默认 1800s（30 分钟）
///   - maxEntries: Hm_lvt 最多保留条数，默认 4
///   - windowSeconds: 窗口长度（秒），超出最早的时间将被删除，默认 30 天 = 2_592_000 秒
///   - ageSeconds: cookie 过期秒数（用于生成 HTTPCookie 的 expiresDate），默认一年
///   - domain: 写入 cookie 的域（必须提供真实域名或以点开头的二级域）
///
/// - Returns: 更新后的 lvt 字符串、lpvt 字符串，以及对应的 HTTPCookie（便于直接加入 HTTPCookieStorage）
public func updateHmCookies(
    siteId: String,
    existingLvt: String?,
    existingLpvt: String?,
    nowSeconds: Int = Int(Date().timeIntervalSince1970),
    vdur: Int = 1800,
    maxEntries: Int = 4,
    windowSeconds: Int = 2_592_000,
    ageSeconds: Int = 31_536_000,
    domain: String
) -> (lvt: String, lpvt: String, cookies: [HTTPCookie]) {
    
    // helper: parse comma-separated timestamps into Int array
    func parseTimestamps(_ s: String?) -> [Int] {
        guard let s = s, !s.isEmpty else { return [] }
        return s.split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 > 0 }
    }
    
    var arr = parseTimestamps(existingLvt)
    let lastPv = Int(existingLpvt ?? "0") ?? 0
    let now = nowSeconds
    
    // 删除窗口之外的最老记录（30天之外）
    while let first = arr.first, (now - first) > windowSeconds {
        arr.removeFirst()
    }
    
    // 如果与上次 pageview 的时间差大于 vdur，视为新一次 pageview -> 加入当前时间
    if (now - lastPv) > vdur {
        arr.append(now)
    }
    
    // 保留最多 maxEntries（保留最近的几条）
    while arr.count > maxEntries {
        arr.removeFirst()
    }
    
    // 如果之前没有 lvt（首次），确保至少有当前时间
    if arr.isEmpty {
        arr = [now]
    }
    
    let newLvt = arr.map(String.init).joined(separator: ",")
    let newLpvt = String(now)
    
    // 生成 HTTPCookie 对象以便写入 HTTPCookieStorage
    func cookie(name: String, value: String) -> HTTPCookie? {
        var props: [HTTPCookiePropertyKey: Any] = [
            .name: name,
            .value: value,
            .path: "/",
            .domain: domain,
            .expires: Date(timeIntervalSinceNow: TimeInterval(ageSeconds))
        ]
        // 可选：设置 HttpOnly/secure 等，根据需要调整
        props[.secure] = true
        // props[.init("HttpOnly")] = true // HTTPCookie 不直接支持 HttpOnly 属性设置为 true via keys in all contexts
        
        return HTTPCookie(properties: props)
    }
    
    var cookies: [HTTPCookie] = []
    if let c1 = cookie(name: "Hm_lvt_\(siteId)", value: newLvt) { cookies.append(c1) }
    if let c2 = cookie(name: "Hm_lpvt_\(siteId)", value: newLpvt) { cookies.append(c2) }
    
    return (lvt: newLvt, lpvt: newLpvt, cookies: cookies)
}

//#Playground {
//    let js = """
//(function() {
//    var h = {},
//        mt = {},
//        c = {
//            id: "fe102b73da12a08f8aee7f4b96f4709a",
//            dm: ["koalaclouds.com"],
//            js: "tongji.baidu.com/hm-web/js/",
//            etrk: [],
//            cetrk: [],
//            cptrk: [],
//            icon: '',
//            ctrk: [],
//            vdur: 1800000,
//            age: 31536000000,
//            qiao: 0,
//            pt: 0,
//            spa: 0,
//            aet: '',
//            hca: '24F8A216812BCA2E',
//            ab: '0',
//            v: 1
//        };
//"""
//    let account = try extractHMAccount(js)
//    let id = try extractID(js)
//    let domains = try extractDomains(js)
//    let _ = updateHmCookies(siteId: id, existingLvt: nil, existingLpvt: nil, domain: domains.first ?? "/")
//}
