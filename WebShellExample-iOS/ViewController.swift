//
//  ViewController.swift
//  WebShellExample-iOS
//
//  Created by virus1993 on 2018/3/1.
//  Copyright © 2018年 ascp. All rights reserved.
//

import UIKit
import WebShell_iOS

/// 下载状态数据模型，用于视图数据绑定
struct DownloadInfo {
    weak var riffle : PCWebRiffle?
    var createTime = Date(timeIntervalSince1970: 0)
    var name = ""
    var progress = ""
    var totalBytes = ""
    var site = ""
    var state = ""

    init(task: PCDownloadTask) {
        riffle = task.request.riffle
        name = task.fileName
        progress = "\(task.pack.progress * 100)%"
        totalBytes = "\(Float(task.pack.totalBytes) / 1024.0 / 1024.0)M"
        site = task.request.riffle!.mainURL!.host!
        createTime = task.createTime
    }
    
    init(riffle: PCWebRiffle) {
        self.riffle = riffle
        name = riffle.mainURL!.absoluteString
        site = riffle.mainURL!.host!
    }
}

class ViewController: UITableViewController {
    var datas = [DownloadInfo]()
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
//        let items = ["http://www.feemoo.com/file-1892482.html",
//                     "http://www.feemoo.com/s/1htfnfyn",
//                     "http://www.feemoo.com/file-1897522.html",
//                     "http://www.666pan.cc/file-532687.html",
//                     "http://www.666pan.cc/file-532273.html",
//                     "http://www.88pan.cc/file-532359.html",
//                     "http://www.ccchoo.com/file-40055.html",
//                     "http://www.ccchoo.com/file-40053.html"]
        let items = ["http://www.chooyun.com/file-51745.html", "http://www.feemoo.com/s/v2j0z15j", "http://www.666pan.cc/file-532641.html"]
        PCPipeline.share.delegate = self
        for item in items {
            let _ = PCPipeline.share.add(url: item, password: "")
        }
    }
    
    @objc func reloadData(notification : Notification) {
        print("Recive Notification !")
        guard let items = notification.object as? [DownloadInfo] else { return }
        self.datas = items
        self.tableView.reloadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    //MARK: - TablevView Delegate
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return datas.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "com.ascp.cell.list", for: indexPath)
        let item = datas[indexPath.row]
        cell.textLabel?.text = item.name
        cell.detailTextLabel?.text = item.progress
        return cell
    }
}

extension ViewController: PCPiplineDelegate {
    func pipline(didAddRiffle riffle: PCWebRiffle) {
        print("\n(((((((((((((((((((((( Pipline didAddRiffle Begin )))))))))))))))))))))))")
        let info = DownloadInfo(riffle: riffle)
        add(info: info)
        print("(((((((((((((((((((((( Pipline didAddRiffle End )))))))))))))))))))))))\n")
    }
    
    func pipline(didUpdateTask task: PCDownloadTask) {
        print("(((((((((((((((((((((( Pipline didUpdateTask Begin )))))))))))))))))))))))")
        let info = DownloadInfo(task: task)
        add(info: info)
        print("(((((((((((((((((((((( Pipline didUpdateTask End )))))))))))))))))))))))")
    }
    
    func pipline(didFinishedTask task: PCDownloadTask, error: Error?) {
        print("\n(((((((((((((((((((((( Pipline didFinishedTask Begin )))))))))))))))))))))))")
        
        print("(((((((((((((((((((((( Pipline didFinishedTask End )))))))))))))))))))))))\n")
    }
    
    func pipline(didFinishedRiffle riffle: PCWebRiffle) {
        print("\n(((((((((((((((((((((( Pipline didFinishedRiffle Begin )))))))))))))))))))))))")
        print("************ Not Found File Link: \(riffle.mainURL?.absoluteString ?? "** no link **")")
        print("(((((((((((((((((((((( Pipline didFinishedRiffle End )))))))))))))))))))))))\n")
    }
    
    func add(info: DownloadInfo) {
        if let index = datas.index(where: {
            if let rif = $0.riffle {
                return rif == info.riffle
            }
            return false
        }) {
            datas[index] = info
            print(">>>>>>>>>>>>>>>>> Update info \(info.name)")
            tableView.reloadRows(at: [IndexPath.init(row: index, section: 0)], with: .none)
        }   else    {
            datas.append(info)
            tableView.reloadData()
            print(">>>>>>>>>>>>>>>>> Add info \(info.name)")
        }
    }
}

