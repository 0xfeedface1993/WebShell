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

class ViewController: NSViewController {
    @IBOutlet var DownloadStateController: NSArrayController!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
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
        
        let pipline = Pipeline.share
        let f1 = pipline.add(url: "http://www.feemoo.com/s/v2j0z15j") as? Feemoo
        f1?.downloadStateController = DownloadStateController
//        print(f1)
        let f2 = pipline.add(url: "http://www.feemoo.com/s/313qof7s") as? Feemoo
        f2?.downloadStateController = DownloadStateController
//        print(f2)
        //
        
//        let feemoo = Feemoo(urlString: "http://www.feemoo.com/s/v2j0z15j")
//        feemoo.downloadStateController = DownloadStateController
//        pipline.add(riffle: feemoo)
//        feemoo.begin()
        
        let fz1 = pipline.add(url: "http://www.88pan.cc/file-532641.html") as? Pan666
        fz1?.downloadStateController = DownloadStateController
//        print(fz1)
        let fz2 = pipline.add(url: "http://www.88pan.cc/file-530009.html") as? Pan666
        fz2?.downloadStateController = DownloadStateController
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
