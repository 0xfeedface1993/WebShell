//
//  PCPipline.swift
//  WebShellExsample
//
//  Created by virus1993 on 2018/4/19.
//  Copyright © 2018年 ascp. All rights reserved.
//

import Foundation

let unkonwGroupName = "unkown-site-group"
let GroupDefaultRule = "\\.[^\\.]+\\."

/// 流水线上的一道产品线，管理一个站点下所有的任务
public class PCPiplineSeat {
    var site : WebHostSite = .unknowsite
    var finished = [PCWebRiffle]()
    var working = [PCWebRiffle]()
    private var pipline = PCPipeline.share
    private var timer: Timer?
    private var lastDownloadTime: Date?
    
    init(site: WebHostSite) {
        self.site = site
        print(">>>>>>>> Add group \(self.site) !")
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
        
        if working.count >= 1    {
            if working[0].isFinished == false {
                working[0].begin()
            }   else    {
                finished.append(working[0])
                working.remove(at: 0)
                
                defer {
                    run()
                }
                
                guard let _ = PCDownloadManager.share.tasks.index(where: { $0.request.riffle?.mainURL == finished.last!.mainURL && $0.request.isFileDownloadTask }) else {
                    pipline.delegate?.pipline?(didFinishedRiffle: finished.last!)
                    return
                }
            }
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
        
        // 任务完成要确定为文件下载并且下载完成标签为真时才执行下一个任务
        if working.first?.isFinished == true {
            run()
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
    
    public func add<T: PCWebRiffle>(url: String) -> T? {
        guard let host = URL(string: url) else {
            return nil
        }
        
        let type = siteType(url: host)
        switch type {
        case .feemoo:
            let riffle = Feemoo(urlString: url)
            riffle.host = type
            add(riffle: riffle)
            return riffle as? T
        case .pan666:
            let riffle = Pan666(urlString: url)
            riffle.host = type
            add(riffle: riffle)
            return riffle as? T
        case .cchooo:
            let riffle = Ccchooo(urlString: url)
            riffle.host = type
            add(riffle: riffle)
            return riffle as? T
        case .unknowsite:
            print("unkown site!")
            return nil
        }
    }
    
    /// 根据riffle找到对应的站点序列元素位置
    ///
    /// - Parameter riffle: riffle对象
    /// - Returns: 若没有对应的位置，则返回nil
    func find(withRiffle riffle: PCWebRiffle) -> Int? {
        return workers.index(where: { (seat) -> Bool in
            return (seat.finished.first(where: { $0.host == riffle.host }) != nil) || (seat.working.first(where: { $0.host == riffle.host }) != nil)
        })
    }
    
    /// 根据站点类型找到对应的站点序列元素位置
    ///
    /// - Parameter Hose: 站点类型
    /// - Returns: 位置
    func find(withHost Hose: WebHostSite) -> Int? {
        return workers.index(where: { (seat) -> Bool in
            return (seat.finished.first!.host == Hose) || (seat.working.first!.host == Hose)
        })
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
    case unknowsite
}

public struct SitePack {
    var regulerExpression : String
    var site : WebHostSite
    public static let allSite = [SitePack(regulerExpression: "feemoo", site: .feemoo),
                                 SitePack(regulerExpression: "\\.\\d{2,}pan\\.", site: .pan666),
                                 SitePack(regulerExpression: "(ccchoo)|(chooyun)", site: .cchooo)]
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
