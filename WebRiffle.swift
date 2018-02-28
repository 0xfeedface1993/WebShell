//
//  WebRiffle.swift
//  CCCHOOO
//
//  Created by virus1993 on 2018/2/24.
//  Copyright © 2018年 ascp. All rights reserved.
//

import AppKit
import WebKit

let RiffleFinishedOneDownloadTaskNotificationName = NSNotification.Name("com.ascp.finish.download.one.task")

enum NotificationDownloadFinishedState {
    case normal
    case parserError
}

public protocol WebRiffleProtocol {
    func begin()
}

public class WebRiffle : NSObject, WebRiffleProtocol {
    /// 下载首页url
    var mainURL : URL?
    /// webview实例, 不需要展示给用户，每个站点都独自拥有一个实例，方便并行下载和管理
    var webView : WKWebView!
    /// WebBullet数组，按执行顺序排列
    var bullets = [WebBullet]()
    /// 当前页面WebBullet
    var currentResult : WebBullet?
    /// 迭代器，用于获取下一个页面WebBullet实例
    var bulletsIterator : IndexingIterator<[WebBullet]>?
    /// 是否需要验证码，有些站点错误的验证码也能下载，默认是true
    var isVerifyCodeRequire = true
    /// 对应js脚本名称
    var scriptName : String {
        return ""
    }
    /// js脚本, 包含基础自定义页面方法
    lazy var functionScript : String = {
        if let file = Bundle(for: type(of: self)).url(forResource: scriptName, withExtension: "js") {
            do {
                let str = try String(contentsOf: file)
                return str
            }   catch {
                print(error)
                return ""
            }
        }
        return ""
    }()
    /// 站点类别
    var host : WebHostSite = .unknowsite
    /// web序列是否执行完成
    var isFinished = false
    
    /// 当前验证码窗口
    var promotViewController : VerifyCodeViewController? {
        return NSApp.windows.first(where: { (w) -> Bool in
            guard w.contentViewController?.isKind(of: VerifyCodeViewController.self) ?? false else {
                return false
            }
            let vc = w.contentViewController as! VerifyCodeViewController
            return vc.presentingRiffle == self
        })?.contentViewController as? VerifyCodeViewController
    }
    
    
    /// 初始化，webview实例创建，js脚本注入
    override init() {
        super.init()
        let userController = WKUserContentController()
        let script = WKUserScript(source: functionScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        userController.addUserScript(script)
        let config = WKWebViewConfiguration()
        config.userContentController = userController
        webView = WKWebView(frame: CGRect.zero, configuration: config)
        webView.navigationDelegate = self
    }
    
    deinit {
        webView.stopLoading()
        webView.navigationDelegate = nil
    }
    
    //MARK: - 验证码页面
    func show(verifyCode: NSImage, confirm: ((String)->())?, reloadWay: ((NSImageView)->())?, withRiffle riffle: WebRiffle?) {
        let vc = VerifyCodeViewController(riffle: riffle)
        vc.tap = { code in
            confirm?(code)
            vc.dismiss(nil)
        }
        vc.reloadImage = reloadWay
        vc.codeView.imageView.image = verifyCode
        let topViewController = NSApp.mainWindow?.contentViewController
        topViewController?.presentViewControllerAsModalWindow(vc)
    }
    
    //MARK: - 通知事件
    func downloadFinished() {
        isFinished = true
        NotificationCenter.default.post(name: RiffleFinishedOneDownloadTaskNotificationName, object: self)
    }
    
    public func begin() {
        assertionFailure("Class WebRiffle is abstract class, you should use it's subclass, then confirm WebRiffleProtocol!")
    }
}

extension WebRiffle : WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("didFail navigation withError: \(error)")
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("didFailProvisionalNavigation navigation withError: \(error)")
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("finish load: \(navigation.debugDescription)")
        execNextCommand()
    }
    
    /// 跳转下一个页面并支持执行多个js指令序列
    func execNextCommand() {
        DispatchQueue.global().async {
            if let result = self.currentResult {
                for js in result.injectJavaScript {
                    let sem = DispatchSemaphore(value: 0)
                    DispatchQueue.main.async {
                        self.webView.evaluateJavaScript(js.script, completionHandler: { (data, err) in
                            if let e = err {
                                js.failedAction?(e)
                                print("error : \(e)")
                                sem.signal()
                                return
                            }
                            js.successAction?(data)
                            print("sucess : \(result.method)")
                            sem.signal()
                        })
                    }
                    sem.wait()
                    let _ = self.currentResult?.injectJavaScript.removeFirst()
                    if !js.isAutomaticallyPass {
                        print("pause")
                        return
                    }
                }
                self.currentResult = self.bulletsIterator?.next()
                if let result = self.currentResult {
                    DispatchQueue.main.async {
                        self.webView.load(result.request)
                    }
                }
            }
        }
    }
}
