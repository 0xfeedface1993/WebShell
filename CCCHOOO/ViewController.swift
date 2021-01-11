//
//  ViewController.swift
//  CCCHOOO
//
//  Created by virus1993 on 2018/1/23.
//  Copyright © 2018年 ascp. All rights reserved.
//

import Cocoa
import WebKit
import WebShell

/// 下载状态数据模型，用于视图数据绑定
public class DownloadInfo : NSObject {
    weak var riffle : PCWebRiffle?
    public var createTime = Date(timeIntervalSince1970: 0)
    @objc public dynamic var name = ""
    @objc public dynamic var progress = ""
    @objc public dynamic var totalBytes = ""
    @objc public dynamic var site = ""
    @objc public dynamic var state = ""
    override init() {
        super.init()
    }
    
    init(task: PCDownloadTask) {
        super.init()
        riffle = task.request.riffle
        name = task.fileName
        progress = "\(task.pack.progress * 100)%"
        totalBytes = "\(Float(task.pack.totalBytes) / 1024.0 / 1024.0)M"
        site = task.request.riffle!.mainURL!.host!
        createTime = task.createTime
    }
    
    init(riffle: PCWebRiffle) {
        super.init()
        self.riffle = riffle
        name = riffle.mainURL!.absoluteString
        site = riffle.mainURL!.host!
    }
}

class ViewController: NSViewController {
    @IBOutlet var DownloadStateController: NSArrayController!
    
    @IBOutlet weak var codeView: NSImageView!
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        NotificationCenter.default.addObserver(forName: ImageFetchNotification, object: nil, queue: OperationQueue.main) { (note) in
            if let image = note.object as? ImageMaker {
                self.codeView.image = image.shareImage
            }
        }
        
//        webview.load(currentResult!.request)
//        load666PanSequence(urlString: "")
//        var vc = VerifyCodeViewController(riffle: nil)
//        vc.tap = { code in
//            print(code)
//        }
//        vc.reloadImage = { image in
//            image.image = nil
//        }
//        vc.codeView.imageView.image = NSImage(named: NSImage.Name.init("0a1f-26-01-37"))
//        presentViewControllerAsModalWindow(vc)
//
//        vc = VerifyCodeViewController(riffle: nil)
//        vc.tap = { code in
//            print(code)
//        }
//        vc.reloadImage = { image in
//            image.image = nil
//        }
//        vc.codeView.imageView.image = NSImage(named: NSImage.Name.init("0a1f-26-01-37"))
//        presentViewControllerAsModalWindow(vc)
        
        let pipline = PCPipeline.share
        pipline.delegate = self
//        let items = ["http://www.ccchoo.com/file-40052.html",
//                     "http://www.ccchoo.com/file-40053.html",
//                     "http://www.ccchoo.com/file-40055.html",
//                     "http://www.666pan.cc/file-533064.html",
//                     "http://www.666pan.cc/file-532273.html",
//                     "http://www.88pan.cc/file-532359.html",
//                     "http://www.666pan.cc/file-532687.html"]
//        let items = ["http://www.feemoo.com/file-1892482.html",http://www.feemoo.com/s/v2j0z15j
//                     "http://www.feemoo.com/s/1htfnfyn",
//                     "http://www.feemoo.com/file-1897522.html",
//                     "http://www.666pan.cc/file-532687.html",
//                     "http://www.666pan.cc/file-532273.html",
//                     "http://www.88pan.cc/file-532359.html",
//                     "http://www.ccchoo.com/file-40055.html",
//                     "http://www.ccchoo.com/file-40053.html"]http://www.chooyun.com/file-51745.html
        let items = ["http://www.onstclouds.com/file/QUExMzAzMDQw.html"]//, "http://www.chooyun.com/file-51745.html", "http://www.feemoo.com/s/v2j0z15j", "http://www.ccchoo.com/file-40052.html", "http://www.feemoo.com/file-1897522.html"
//        let items = ["http://www.chooyun.com/file-96683.html"]
        for item in items {
            if let k: XueQiu = pipline.add(url: item, password: "", friendName: "ssss") {
                print(">>> K: \(k)")
            }
        }
        
//        let request = TBRequest
//        TBPipline.share.add(task: request)
        
//        let date = Date()
//        let dateFormater = DateFormatter()
//        dateFormater.dateFormat = "yyyy-MM-dd-HH:mm:SS-"
//        print(dateFormater.string(from: date) + "saveFileName.zip")
        
//        let parts = "fileName。daf.昆明理工.zip".split(separator: ".")
//        let last = String(parts.last ?? "")
//        let prefix = String(parts.dropLast().joined())
//        print("\(prefix)(\("无密码")).\(last)")
        
//        let f1 = pipline.add(url: "http://www.feemoo.com/s/v2j0z15j") as? Feemoo
//        f1?.downloadStateController = DownloadStateController
//        print(f1)
//        let f2 = pipline.add(url: "http://www.feemoo.com/s/313qof7s") as? Feemoo
//        f2?.downloadStateController = DownloadStateController
//        print(f2)
        //
        
//        let feemoo = Feemoo(urlString: "http://www.feemoo.com/s/v2j0z15j")
//        feemoo.downloadStateController = DownloadStateController
//        pipline.add(riffle: feemoo)
//        feemoo.begin()
        
//        let fz1 = pipline.add(url: "http://www.88pan.cc/file-532641.html") as? Pan666
//        fz1?.downloadStateController = DownloadStateController
//        print(fz1)
//        let fz2 = pipline.add(url: "http://www.88pan.cc/file-530009.html") as? Pan666
//        fz2?.downloadStateController = DownloadStateController
//        print(fz2)
        
//        let feemoo2 = Pan666(urlString: "http://www.88pan.cc/file-532641.html")
//        feemoo2.downloadStateController = DownloadStateController
//        pipline.add(riffle: feemoo2)
//        feemoo2.begin()
//
//        let feemoo2 = Pan666(urlString: "http://www.88pan.cc/file-530009.html")
//        feemoo2.downloadStateController = DownloadStateController
//        feemoo2.begin()
//
//        let feemoo3 = Ccchooo(urlString: "http://www.ccchoo.com/down-51745.html")
//        feemoo3.downloadStateController = DownloadStateController
//        feemoo3.begin()
        
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}

extension ViewController : PCPiplineDelegate {
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
        if let items = DownloadStateController.content as? [DownloadInfo] {
            var newItems = items
            if let index = newItems.firstIndex(where: {
                if let rif = $0.riffle {
                    return rif == info.riffle
                }
                return false
            }) {
                newItems[index] = info
                DownloadStateController.content = newItems
                print(">>>>>>>>>>>>>>>>> Update info \(info.name)")
            }   else    {
                DownloadStateController.content = newItems + [info]
                print(">>>>>>>>>>>>>>>>> Add info \(info.name)")
            }
        }   else    {
            DownloadStateController.content = [info]
            print(">>>>>>>>>>>>>>>>> Add info \(info.name)")
        }
    }
}
