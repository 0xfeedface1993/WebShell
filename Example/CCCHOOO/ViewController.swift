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
#if COMBINE_LINUX && canImport(CombineX)
import CombineX
#else
import Combine
#endif

class ViewController: NSViewController {
    @IBOutlet var DownloadStateController: NSArrayController!
    
    @IBOutlet weak var codeView: NSImageView!
    
    var cancellable: AnyCancellable?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
//        let link = "https://www.iycdn.com/file-213019.html"
//
//        cancellable = TowerGroup("load_down_addr2")
//            .join(PHPLinks())
//            .join(Saver(.override))
//            .publisher(for: link)
//            .sink { complete in
//                switch complete {
//                case .finished:
//                    break
//                case .failure(let error):
//                    print(">>> download error \(error)")
//                }
//            } receiveValue: { url in
//                print(">>> download file at \(url)")
//            }
        
//        let link = "http://www.xueqiupan.com/file-672734.html"
//
//        cancellable = DownPage(.default)
//            .join(PHPLinks())
//            .join(Saver(.override))
//            .publisher(for: link)
//            .sink { complete in
//                switch complete {
//                case .finished:
//                    break
//                case .failure(let error):
//                    print(">>> download error \(error)")
//                }
//            } receiveValue: { url in
//                print(">>> download file at \(url)")
//            }
        
//        let link = "https://rosefile.net/6emc775g2p/s_MTGBHJKL.rar.html"
//        cancellable = AppendDownPath()
//            .join(FileIDStringInDomSearchGroup(.loadDownAddr1))
//            .join(GeneralLinks())
//            .join(Saver())
//            .publisher(for: link)
//            .sink { complete in
//                switch complete {
//                case .finished:
//                    break
//                case .failure(let error):
//                    print(">>> download error \(error)")
//                }
//            } receiveValue: { url in
//                print(">>> download file at \(url)")
//            }
        
        let link = "http://www.xunniu-pan.com/file-4067902.html"

        cancellable = RedirectEnablePage()
            .join(DownPage(.default))
            .join(PHPLinks())
            .join(Saver(.override))
            .publisher(for: link)
            .sink { complete in
                switch complete {
                case .finished:
                    break
                case .failure(let error):
                    print(">>> download error \(error)")
                }
            } receiveValue: { url in
                print(">>> download file at \(url)")
            }
            
//        let link = "http://www.xingyaoclouds.com/fs/2l66xn9ubrzzwba"
//        cancellable = RedirectEnablePage()
//            .join(ActionDownPage())
//            .join(PHPLinks())
//            .join(Saver(.override))
//            .publisher(for: link)
//            .sink { complete in
//                switch complete {
//                case .finished:
//                    break
//                case .failure(let error):
//                    print(">>> download error \(error)")
//                }
//            } receiveValue: { url in
//                print(">>> download file at \(url)")
//            }
        
//        let link = "http://www.expfile.com/file-1622046.html"
//        cancellable = RedirectEnablePage()
//            .join(FileListURLRequestGenerator(.default).action("load_down_addr1"))
//            .join(CDLinks())
//            .join(Saver(.override))
//            .publisher(for: link)
//            .sink { complete in
//                switch complete {
//                case .finished:
//                    break
//                case .failure(let error):
//                    print(">>> download error \(error)")
//                }
//            } receiveValue: { url in
//                print(">>> download file at \(url)")
//            }
        
//        let link = "www.rarp.cc/fs/2xx9qxy9bgbbrwb"
//        cancellable = HTTPString()
//            .join(RedirectEnablePage())
//            .join(FileListURLRequestInPageGenerator(.downProcess4, action: "load_down_addr5"))
//            .join(PHPLinks())
//            .join(Saver(.override))
//            .publisher(for: link)
//            .sink { complete in
//                switch complete {
//                case .finished:
//                    break
//                case .failure(let error):
//                    print(">>> download error \(error)")
//                }
//            } receiveValue: { url in
//                print(">>> download file at \(url)")
//            }
    //https://www.567yun.cn/file-2228687.html
//        2228695
//        let link = "https://www.567yun.cn/file-2228692.html"
//        cancellable = RedirectEnablePage()
//            .join(SignFileListURLRequestGenerator(.default, action: "load_down_addr10"))
//            .join(PHPLinks())
//            .join(Saver(.override))
//            .publisher(for: link)
//            .sink { complete in
//                switch complete {
//                case .finished:
//                    break
//                case .failure(let error):
//                    print(">>> download error \(error)")
//                }
//            } receiveValue: { url in
//                print(">>> download file at \(url)")
//            }
        
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
//        
//        let pipline = PCPipeline.share
//        pipline.delegate = self
////        let items = ["http://www.ccchoo.com/file-40052.html",
////                     "http://www.ccchoo.com/file-40053.html",
////                     "http://www.ccchoo.com/file-40055.html",
////                     "http://www.666pan.cc/file-533064.html",
////                     "http://www.666pan.cc/file-532273.html",
////                     "http://www.88pan.cc/file-532359.html",
////                     "http://www.666pan.cc/file-532687.html"]
////        let items = ["http://www.feemoo.com/file-1892482.html",http://www.feemoo.com/s/v2j0z15j
////                     "http://www.feemoo.com/s/1htfnfyn",
////                     "http://www.feemoo.com/file-1897522.html",
////                     "http://www.666pan.cc/file-532687.html",
////                     "http://www.666pan.cc/file-532273.html",
////                     "http://www.88pan.cc/file-532359.html",
////                     "http://www.ccchoo.com/file-40055.html",
////                     "http://www.ccchoo.com/file-40053.html"]http://www.chooyun.com/file-51745.html
//        let items = ["http://www.upfilex.com/file/QUE5MzkyMTM=.html"]//, "http://www.chooyun.com/file-51745.html", "http://www.feemoo.com/s/v2j0z15j", "http://www.ccchoo.com/file-40052.html", "http://www.feemoo.com/file-1897522.html"
////        let items = ["http://www.chooyun.com/file-96683.html"]
//        for item in items {
//            if let k: XueQiu = pipline.add(url: item, password: "", friendName: "ssss") {
//                print(">>> K: \(k)")
//            }
//        }
        
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
