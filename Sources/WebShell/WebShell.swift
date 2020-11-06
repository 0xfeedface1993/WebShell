//
//  PCPipline.swift
//  WebShellExsample
//
//  Created by virus1993 on 2018/4/19.
//  Copyright © 2018年 ascp. All rights reserved.
//

import Foundation
import WebKit

let unkonwGroupName = "unkown-site-group"
let GroupDefaultRule = "\\.[^\\.]+\\."

/// 流水线上的一道产品线，管理一个站点下所有的任务
public class PCPiplineSeat: Logger {
    private var pipline = PCPipeline.share
    var webView : WKWebView!
    var site : WebHostSite = .unknowsite
    /// 已完成下载+下载失败队列项
    public var finished = [PCWebRiffle]()
    /// 正在下载+待下载队列
    public var working = [PCWebRiffle]()
    /// 用于处理下载间隔定时器
    private var timer: Timer?
    /// 上次下载开始时间，一般的网盘两次下载都要10分钟的下载间隔
    private var lastDownloadTime: Date?
    
    init(site: WebHostSite) {
        self.site = site
        print(">>>>>>>> Add group \(self.site) !")
        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: CGRect.zero, configuration: config)
        webView.customUserAgent = userAgent
    }
    
    /// 添加下载任务，若任务不属于该序列的站点则不添加
    ///
    /// - Parameter request: 下载任务请求
    func add(riffle: PCWebRiffle) {
        working.append(riffle)
        riffle.seat = self
        print("Add request \(riffle.host) in group \(self.site) !")
        if working.count == 1 {
            run()
        }
//        if timer == nil {
//            timer = Timer(fire: Date(), interval: 10 * 60, repeats: true) { (t) in
//                if self.isTimeWallPatch() {
//                    self.run()
//                }
//            }
//        }
    }
    
    /// 执行下一个下载任务
    func run() {
//        let now = Date()
//
//        if !self.isTimeWallPatch() {
//            print("^^^^^^^^^^^^^^^^ Please Wait \(10 * 60 - now.timeIntervalSince(self.lastDownloadTime!)) Second To Next \(site) ^^^^^^^^^^^^^^^^")
//            return
//        }
//
//        lastDownloadTime = now
        guard working.count > 0 else {
            log(message: "Current no worker in \(self.site).")
            return
        }
        
        guard working[0].isFinished else {
            working[0].begin()
            return
        }
        
        // 将进行中的任务移到完成队列中，默认就是第一个
        finished.append(working[0])
        working.remove(at: 0)
        log(message: "Swap queue, working: \(working.count) finished: \(finished.count)")
        
        defer {
            // 处理完成后继续下一个任务
            run()
        }
        
        guard let last = finished.last else {
            log(message: "No finished Task in \(self.site)")
            return
        }
        
        if PCDownloadManager
            .share
            .tasks
            .firstIndex(where: { $0.request.riffle?.mainURL == last.mainURL && $0.request.isFileDownloadTask }) == nil {
            log(message: "Can't find task for last finished task \(last.mainURL?.absoluteString ?? "Ooops!") in \(self.site), call didFinishedRiffle delegate, I forgot why.")
            pipline.delegate?.pipline?(didFinishedRiffle: last)
        }
    }
    
    /// 监听下载完成通知，若是本序列的下载任务
    ///
    /// - Parameter notification: 通知
    @objc func taskFinished(finishedRiffle: PCWebRiffle) {
        print("----------------- Recive Task download Finish Notification ----------------- ")
        guard finishedRiffle.mainURL == working.first?.mainURL else {
            print("^^^^^^^^^^^ Not working WebRiffle call: \(finishedRiffle.mainURL?.absoluteString ?? "*** no main url ***") ^^^^^^^^^^^")
            return
        }
        
        defer {
            run()
        }
        
        // 任务完成要确定为文件下载并且下载完成标签为真时才执行下一个任务
        if working.first?.isFinished ?? false {
            print("----------------- Run Next Riffle, wokers: \(working.count) -----------------")
        }   else    {
            print("----------------- Current Riffle Not Finish Or Nor wokers, wokers: \(working.count) -----------------")
        }
    }
    
    /// 检查间隔下载时间是否到10分钟了
    ///
    /// - Returns: 若间隔时间未到则返回false
    func isTimeWallPatch() -> Bool {
        let now = Date()
        
        if let last = lastDownloadTime {
            return now.timeIntervalSince(last) > 10 * 60
        }   else    {
            lastDownloadTime = now
            return true
        }
    }
    
    func remove(riffle: PCWebRiffle) {
        if let index = working.firstIndex(where: { $0.host == riffle.host }) {
            if index == working.startIndex {            
                working[index].downloadFinished()
            }   else    {
                working.remove(at: index)
            }
        }
    }
    
    public func restart(mainURL: URL) {
        if let index = finished.firstIndex(where: { $0.mainURL == mainURL }) {
            let item = finished[index]
            item.isFinished = false
            let downloadManager = PCDownloadManager.share
            if let downloadIndex = downloadManager.tasks.firstIndex(where: { $0.request.riffle?.mainURL == mainURL }) {
                print("########### Remove Download Task for \(mainURL.absoluteString) ###########")
                downloadManager.tasks.remove(at: downloadIndex)
            }
            print("########### Remove Riffle from finished group ###########")
            finished.remove(at: index)
            print("########### Add Riffle to Pipiline ###########")
            pipline.add(riffle: item)
        }
    }
}

/// 流水线情况代理，状态更新调用
@objc public protocol PCPiplineDelegate {
    @objc optional func pipline(didAddRiffle riffle: PCWebRiffle)
    // 只有在解析过程中无法获取下载地址时才被调用
    @objc optional func pipline(didFinishedRiffle riffle: PCWebRiffle)
    @objc optional func pipline(didUpdateTask task: PCDownloadTask)
    @objc optional func pipline(didFinishedTask task: PCDownloadTask)
}


/// 流水线作业
public class PCPipeline {
    private static let _pipline = PCPipeline()
    public static var share : PCPipeline {
        return _pipline
    }
    
    /// 分类，每个woker管理一个站点下的所有WebRiffle
    var workers = [PCPiplineSeat]()
    public var allWorkers: [PCPiplineSeat] {
        return workers
    }
    
    public weak var delegate : PCPiplineDelegate?
    
    /// 添加WebRiffle，自动按序列顺序执行
    ///
    /// - Parameter riffle: WebRiffle
    func add(riffle: PCWebRiffle) {
        if let index = find(withRiffle: riffle) {
            workers[index].add(riffle: riffle)
            delegate?.pipline?(didAddRiffle: riffle)
        }   else    {
            let seat = PCPiplineSeat(site: riffle.host)
            workers.append(seat)
            seat.add(riffle: riffle)
            delegate?.pipline?(didAddRiffle: riffle)
        }
    }
    
    public func add<T: PCWebRiffle>(url: String, password: String, friendName: String) -> T? {
        guard let host = URL(string: url) else {
            return nil
        }
        
        let type = siteType(url: host)
        switch type {
        case .feemoo:
            let riffle = Feemoo(urlString: url)
            riffle.password = password
            riffle.host = type
            riffle.friendName = friendName
            add(riffle: riffle)
            return riffle as? T
        case .pan666:
            let riffle = Pan666(urlString: url)
            riffle.password = password
            riffle.host = type
            riffle.friendName = friendName
            add(riffle: riffle)
            return riffle as? T
        case .cchooo:
            let riffle = Ccchooo(urlString: url)
            riffle.password = password
            riffle.host = type
            riffle.friendName = friendName
            add(riffle: riffle)
            return riffle as? T
        case .yousuwp:
            let riffle = Yousuwp(urlString: url)
            riffle.password = password
            riffle.host = type
            riffle.friendName = friendName
            add(riffle: riffle)
            return riffle as? T
        case .v2file:
            let riffle = V2File(urlString: url)
            riffle.password = password
            riffle.host = type
            riffle.friendName = friendName
            add(riffle: riffle)
            return riffle as? T
        case .xunniu:
            let riffle = XunNiu(urlString: url)
            riffle.password = password
            riffle.host = type
            riffle.friendName = friendName
            add(riffle: riffle)
            return riffle as? T
        case .xi:
            let riffle = Xipan(urlString: url)
            riffle.password = password
            riffle.host = type
            riffle.friendName = friendName
            add(riffle: riffle)
            return riffle as? T
        case .bus:
            let riffle = BusPan(urlString: url)
            riffle.password = password
            riffle.host = type
            riffle.friendName = friendName
            add(riffle: riffle)
            return riffle as? T
        case .color:
            let riffle = ColorDx(urlString: url)
            riffle.password = password
            riffle.host = type
            riffle.friendName = friendName
            add(riffle: riffle)
            return riffle as? T
        case .unknowsite:
            print("unkown site!")
            return nil
        case .kuyun:
            let riffle = KuYun(urlString: url)
            riffle.password = password
            riffle.host = type
            riffle.friendName = friendName
            add(riffle: riffle)
            return riffle as? T
        }
    }
    
    /// 根据riffle找到对应的站点序列元素位置
    ///
    /// - Parameter riffle: riffle对象
    /// - Returns: 若没有对应的位置，则返回nil
    func find(withRiffle riffle: PCWebRiffle) -> Int? {
        return workers.firstIndex(where: { (seat) -> Bool in
            return (seat.finished.first(where: { $0.host == riffle.host }) != nil) || (seat.working.first(where: { $0.host == riffle.host }) != nil)
        })
    }
    
    /// 根据站点类型找到对应的站点序列元素位置
    ///
    /// - Parameter Hose: 站点类型
    /// - Returns: 位置
    func find(withHost Hose: WebHostSite) -> Int? {
        return workers.firstIndex(where: { (seat) -> Bool in
            if let ff = seat.finished.first {
                return ff.host == Hose
            }
            
            if let wf = seat.working.first {
                return wf.host == Hose
            }
            
            return false
        })
    }
    
    /// 删除Riffle，完成队列和未完成队列里面的都删除
    ///
    /// - Parameter riffle: 需要删除的Riffle
    public func remove(riffle: PCWebRiffle) {
        if let index = find(withHost: riffle.host) {
            workers[index].remove(riffle: riffle)
        }
    }
}

extension String {
    /// 获取站点中间名
    ///
    /// - Parameter url: 站点url字符串
    /// - Returns: 若找到站点字符串则返回，否则返回nil
    func siteParser(rule: String) -> String {
        do {
            let regx = try NSRegularExpression(pattern: rule, options: NSRegularExpression.Options.caseInsensitive)
            let strNS = self as NSString
            if let result = regx.firstMatch(in: self, options: NSRegularExpression.MatchingOptions.reportProgress, range: NSRange(location: 0, length: strNS.length)) {
                let name = strNS.substring(with: result.range)
                return name
            }
            return unkonwGroupName
        } catch {
            print("regx: \(rule), \(error)")
            return unkonwGroupName
        }
    }
    
    static func find(host: String, regulerExpression: String) -> (status: Bool, name: String) {
        do {
            let regx = try NSRegularExpression(pattern: regulerExpression, options: NSRegularExpression.Options.caseInsensitive)
            let strNS = host as NSString
            if let result = regx.firstMatch(in: host, options: NSRegularExpression.MatchingOptions.reportProgress, range: NSRange(location: 0, length: strNS.length)) {
                return (true, strNS.substring(with: result.range))
            }
            return (false, "")
        } catch {
            print("regx: \(regulerExpression), \(error)")
            return (false, "")
        }
    }
}

public enum WebHostSite : Int {
    case feemoo
    case pan666
    case cchooo
    case yousuwp
    case v2file
    case xunniu
    case xi
    case bus
    case color
    case kuyun
    case unknowsite
}

public struct SitePack {
    var regulerExpression : String
    var site : WebHostSite
    public static let allSite = [SitePack(regulerExpression: "(feemoo)|(fmpan)", site: .feemoo),
                                 SitePack(regulerExpression: "\\.\\d{2,}pan\\.", site: .pan666),
                                 SitePack(regulerExpression: "(ccchoo)|(chooyun)|(caihoo)|(wodech)|(mm222)|(getlle)", site: .cchooo),
                                 SitePack(regulerExpression: "yousuwp", site: .yousuwp),
                                 SitePack(regulerExpression: "xun\\-niu", site: .xunniu),
                                 SitePack(regulerExpression: "xibupan", site: .xi),
                                 SitePack(regulerExpression: "(v2file)|(wa54)|(wp2ef)|(wp344)|(wp8ky)", site: .v2file),
                                 SitePack(regulerExpression: "ibuspan", site: .bus),
                                 SitePack(regulerExpression: "(coofiles)|(kufiles)", site: .color),
                                 SitePack(regulerExpression: "(coolcloudx)|(onstclouds)|(kufile)", site: .kuyun)]
}

public func siteType(url: URL) -> WebHostSite {
    guard let host = url.host else {
        return .unknowsite
    }
    
    let sites = SitePack.allSite
    for site in sites {
        if String.find(host: host, regulerExpression: site.regulerExpression).status {
            return site.site
        }
    }
    return .unknowsite
}
