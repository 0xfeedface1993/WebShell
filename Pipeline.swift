//
//  Pipeline.swift
//  WebShell
//
//  Created by virus1993 on 2018/2/26.
//  Copyright © 2018年 ascp. All rights reserved.
//

#if TARGET_OS_MAC
    import Cocoa
#elseif TARGET_OS_IPHONE
    import UIKit
#endif

let unkonwGroupName = "unkown-site-group"
let GroupDefaultRule = "\\.[^\\.]+\\."

public class PiplineSeat {
    var site : WebHostSite = .unknowsite
    var riffles = [WebRiffle]()
    private var currentRiffle : WebRiffle?
    
    init(site: WebHostSite) {
        self.site = site
        NotificationCenter.default.addObserver(self, selector: #selector(taskFinished(notification:)), name: RiffleFinishedOneDownloadTaskNotificationName, object: nil)
        print("Add group \(self.site) !")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: RiffleFinishedOneDownloadTaskNotificationName, object: nil)
    }
    
    /// 添加下载任务，若任务不属于该序列的站点则不添加
    ///
    /// - Parameter request: 下载任务请求
    func add(riffle: WebRiffle) {
        riffles.append(riffle)
        print("Add request \(riffle.host) in group \(self.site) !")
        run()
    }
    
    /// 监听下载完成通知，若是本序列的下载任务
    ///
    /// - Parameter notification: 通知
    @objc func taskFinished(notification: Notification) {
        print("Recive Task download Finish Notification!")
        guard let finishedRiffle = notification.object as? WebRiffle, finishedRiffle.mainURL == currentRiffle?.mainURL else {
            print("^^^^^^^^^^^ Not a valid WebRiffle notification: \(notification.object ?? "no object rev") ^^^^^^^^^^^")
            return
        }
        
        guard finishedRiffle.isFinished else {
            print("^^^^^^^^^^^ current Riffle is not finished: \(currentRiffle?.mainURL?.absoluteString ?? "no main url") ^^^^^^^^^^^")
            return
        }
        
        run()
    }
    
    /// 执行下一个下载任务
    private func run() {
        if let crq = currentRiffle {
            guard crq.isFinished else { return }
            /// 非本序列的任务和最后一个任务执行完时不执行任何操作
            guard let index = riffles.index(where: { crq == $0 }), index != riffles.index(before: riffles.endIndex) else { return }
            let nextIndex = riffles.index(after: index)
            currentRiffle = riffles[nextIndex]
            print("+++++++++ Next riffle is \(currentRiffle?.mainURL?.absoluteString ?? "no main url")")
            currentRiffle?.begin()
        }   else    {
            /// 第一次下载
            if let riffle = riffles.first {
                currentRiffle = riffle
                print("+++++++++ First riffle is \(riffle.mainURL?.absoluteString ?? "no main url")")
                currentRiffle?.begin()
            }
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
                          SitePack(regulerExpression: "ccchoo", site: .cchooo)]
}

public func site(url: URL) -> WebHostSite {
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

/// 流水线作业
public class Pipeline {
    private static let _pipline = Pipeline()
    public static var share : Pipeline {
        return _pipline
    }
    /// 分类，每个woker管理一个站点下的所有WebRiffle
    var workers = [PiplineSeat]()
    var downloadStateData : [DownloadInfo] {
        let requests = workers.map({ $0.riffles }).flatMap({ $0 }).map({ $0.fileDownloadRequest }).filter({ $0 != nil }).map({ $0! })
        let runningTasks = DownloadManager.share.tasks.filter({ tk in requests.contains(where: { tk.request.request == $0.request }) })
        let infos = runningTasks.map({ DownloadInfo(task: $0) })
        return infos.sorted(by: { $0.createTime > $1.createTime })
    }
    
    /// 添加WebRiffle，自动按序列顺序执行
    ///
    /// - Parameter riffle: WebRiffle
    public func add(riffle: WebRiffle) {
        if let target = workers.first(where: { (seat) -> Bool in
            return (seat.riffles.first(where: { $0.host == riffle.host }) != nil)
        }) {
            target.add(riffle: riffle)
        }   else    {            
            let seat = PiplineSeat(site: riffle.host)
            workers.append(seat)
            seat.add(riffle: riffle)
        }
    }
    
    public func add<T: WebRiffle>(url: String) -> T? {
        guard let host = URL(string: url) else {
            return nil
        }
        
        let type = site(url: host)
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
