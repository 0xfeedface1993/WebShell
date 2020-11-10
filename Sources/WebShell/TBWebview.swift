//
//  TBWebview.swift
//  WebShell_macOS
//
//  Created by virus1994 on 2019/5/27.
//  Copyright © 2019 ascp. All rights reserved.
//

import Cocoa
import WebKit

class TBWebview: NSObject, Logger {
    static let share = TBWebview()
    struct WebPack {
        var site: SitePack
        var delegate: TBWebViewDelegate?
        var webview: WKWebView
    }
    
    var webviews = [WebPack]()
    
    func loadWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        let webview = WKWebView(frame: CGRect.zero, configuration: config)
        webview.customUserAgent = userAgent
        webview.navigationDelegate = self
        return webview
    }
    
    private override init() {
        super.init()
        let packs = SitePack.allSite
        webviews = packs.map({ WebPack(site: $0, delegate: nil, webview: self.loadWebView()) })
    }
    
    func webpack(forSite site: WebHostSite) -> WebPack? {
        return webviews.first(where: { $0.site.site == site })
    }
    
    func rebase(delegate: TBWebViewDelegate, site: WebHostSite) {
        guard let index = webviews.firstIndex(where: { $0.site.site == site }) else { return }
        webviews[index].delegate = delegate
    }
    
    func caller(forWebview webview: WKWebView) -> TBWebViewDelegate? {
        guard let index = webviews.firstIndex(where: { $0.webview == webview }) else {
            log(error: "Webview not find for \(webview)")
            return nil
        }
        
        return webviews[index].delegate
    }
}

extension TBWebview: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let delegate = caller(forWebview: webView)
        delegate?.tbweb(webView: webView, error: nil)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let delegate = caller(forWebview: webView)
        delegate?.tbweb(webView: webView, error: error)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let delegate = caller(forWebview: webView)
        delegate?.tbweb(webView: webView, error: error)
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        let delegate = caller(forWebview: webView)
        delegate?.tbweb(webView: webView, error: nil)
    }
    
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        let delegate = caller(forWebview: webView)
        delegate?.tbweb(webView: webView, error: nil)
    }
}

protocol TBWebViewDelegate {
    func tbweb(webView: WKWebView, error: Error?)
}
