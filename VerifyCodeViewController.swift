//
//  VerifyCodeViewController.swift
//  CCCHOOO
//
//  Created by virus1993 on 2018/2/24.
//  Copyright © 2018年 ascp. All rights reserved.
//

#if TARGET_OS_MAC
    import Cocoa
#elseif TARGET_OS_IPHONE
    import UIKit
#endif

class VerifyCodeViewController: NSViewController {
    let codeView = VerifyCodeView()
    var tap : ((String)->())? {
        set {
            codeView.tap = newValue
        }
        get {
            return codeView.tap
        }
    }
    var reloadImage : ((NSImageView)->())? {
        set {
            codeView.reloadImage = newValue
        }
        get {
            return codeView.reloadImage
        }
    }
    weak var presentingRiffle : WebRiffle?
    
    init(riffle: WebRiffle?) {
        super.init(nibName: NSNib.Name.init("VerifyCodeViewController"), bundle: Bundle(for: type(of: self)))
        self.presentingRiffle = riffle
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        view.addSubview(codeView)
        title = "验证码"
        
        codeView.translatesAutoresizingMaskIntoConstraints = false
        let views = ["v":codeView]
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[v]|", options: [], metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[v]|", options: [], metrics: nil, views: views))
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
//        view.window?.titlebarAppearsTransparent = true
    }
    
}
