//
//  ViewController.swift
//  WebShellExample-iOS
//
//  Created by virus1993 on 2018/3/1.
//  Copyright © 2018年 ascp. All rights reserved.
//

import UIKit
import WebShell_iOS

class ViewController: UITableViewController {
    var datas : [DownloadInfo]?
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
        let items = ["http://www.ccchoo.com/file-40055.html"]
        for item in items {
            guard let _ = Pipeline.share.add(url: item) else { continue }
        }
        
//        NotificationCenter.default.addObserver(forName: WebRiffle.UpdateRiffleDownloadNotification, object: self, queue: OperationQueue.main, using: {
//            guard let items = $0.object as? [DownloadInfo] else { return }
//            self.datas = items
//            self.tableView.reloadData()
//        })
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData(notification:)), name: WebRiffle.UpdateRiffleDownloadNotification, object: nil)
    }
    
    @objc func reloadData(notification : Notification) {
        print("Recive Notification !")
        guard let items = notification.object as? [DownloadInfo] else { return }
        self.datas = items
        self.tableView.reloadData()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: WebRiffle.UpdateRiffleDownloadNotification, object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    //MARK: - TablevView Delegate
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return datas?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "com.ascp.cell.list", for: indexPath)
        let item = datas![indexPath.row]
        cell.textLabel?.text = item.name
        cell.detailTextLabel?.text = item.progress
        return cell
    }
}

