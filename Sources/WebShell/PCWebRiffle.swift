//
//  PCWebRiffle.swift
//  WebShellExsample
//
//  Created by virus1993 on 2018/4/20.
//  Copyright © 2018年 ascp. All rights reserved.
//

import WebKit

#if os(iOS)
let webWindow = UIWindow(frame: UIScreen.main.bounds)
#endif

public class PCWebRiffle: NSObject {
    public var uuid = UUID()
    /// 可视化文件名，可选
    public var friendName = ""
    /// 解压密码
    public var password = ""
    /// 下载首页url
    public var mainURL : URL?
    /// webview实例, 不需要展示给用户，每个站点都独自拥有一个实例，方便并行下载和管理
//    var webView : WKWebView? {
//        return seat?.webView
//    }
    /// 等待执行的WebBullet数组，按执行顺序排列
    var watting = [PCWebBullet]()
    /// 已执行的WebBullet数组，按执行顺序排列
    var finished = [PCWebBullet]()
    /// 是否需要验证码，有些站点错误的验证码也能下载，默认是true
    public var isVerifyCodeRequire = true
    /// 对应js脚本名称
    public var scriptName : String {
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
    public var host : WebHostSite = .unknowsite
    /// web序列是否执行完成
    public var isFinished = false
    /// 验证码错误次数
    public var verifyCodeParserErrorCount : Int {
        didSet {
            print("\(mainURL?.host ?? "") Verify Code Error Count: \(verifyCodeParserErrorCount)")
        }
    }
    let pipline = PCPipeline.share
    public weak var seat : PCPiplineSeat?
    
    /// 初始化，webview实例创建，js脚本注入
    override init() {
        verifyCodeParserErrorCount = 0
        super.init()
    }
    
    public convenience init(mainURL: URL) {
        self.init()
        self.mainURL = mainURL
    }
    
    public required init(urlString: String) {
        verifyCodeParserErrorCount = 0
        super.init()
    }
    
    deinit {
        print("&&& Deinit Riffle &&&")
        seat?.webView.stopLoading()
        seat?.webView.navigationDelegate = nil
    }
    
    //MARK: - 通知事件
    func downloadFinished() {
        print("----------------- Download Finished Note -----------------")
        isFinished = true
        print(">>> updat \(self).isFinished = \(isFinished)")
        DispatchQueue.main.async { [weak self] in
            guard let riffle = self else {
                fatalError("Can't get riffle instance!")
            }
            riffle.seat?.taskFinished(finishedRiffle: riffle)
        }
    }   
    
    public func begin() {
        assertionFailure("Class WebRiffle is abstract class, you should use it's subclass, then confirm WebRiffleProtocol!")
    }
    
    func loadWebView() {
        let userController = WKUserContentController()
        let script = WKUserScript(source: functionScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        userController.addUserScript(script)
        let config = WKWebViewConfiguration()
        config.userContentController = userController
        #if os(iOS)
        seat?.webView.removeFromSuperview()
        seat?.webView = WKWebView(frame: webWindow.bounds, configuration: config)
        #elseif os(macOS)
        seat?.webView = WKWebView(frame: CGRect.zero, configuration: config)
        #endif
        seat?.webView.navigationDelegate = self
        seat?.webView.customUserAgent = userAgent
        #if os(iOS)
        webWindow.addSubview(seat!.webView)
        #endif
    }
}

extension PCWebRiffle : WKNavigationDelegate {
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
        guard self.watting.count > 0 else {
            self.downloadFinished()
            return
        }
        
        DispatchQueue.global().async { [weak self] in
            guard let unit = self?.watting[0] else { return }
            for js in unit.injectJavaScript {
                let sem = DispatchSemaphore(value: 0)
                DispatchQueue.main.async {
                    self?.seat?.webView.evaluateJavaScript(js.script, completionHandler: { (data, err) in
                        if let e = err {
                            js.failedAction?(e)
                            print("******** error : \(e)")
                            sem.signal()
                            return
                        }
                        js.successAction?(data)
                        print(">>>>>>>> sucess : \(unit.method )")
                        sem.signal()
                    })
                }
                sem.wait()
                
                self?.watting[0].finishedJavaScript.append(unit.injectJavaScript[0])
                self?.watting[0].injectJavaScript.remove(at: 0)
                
                if !js.isAutomaticallyPass {
                    print("+++++++++ pause")
                    return
                }
            }
            
            self?.finished.append(unit)
            self?.watting.remove(at: 0)
            
            if let resultx = self?.watting.first {
                DispatchQueue.main.async {
                    self?.seat?.webView.load(resultx.request)
                }
            }
        }
    }
}
