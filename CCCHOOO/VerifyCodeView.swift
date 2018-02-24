//
//  VerifyCodeView.swift
//  CCCHOOO
//
//  Created by virus1993 on 2018/2/24.
//  Copyright © 2018年 ascp. All rights reserved.
//

import Cocoa

/// 验证码输入页面
class VerifyCodeView: NSView {
    let imageView = NSImageView()
    let textField = NSTextField()
    let button = NSButton(title: "确定", target: self, action: #selector(tap(sender:)))
    var tap : ((String)->())?
    var reloadImage : ((NSImageView)->())?

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
    init() {
        super.init(frame: NSRect.zero)
        addSubview(imageView)
        addSubview(textField)
        imageView.isEnabled = true
        imageView.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(tap(sender:))))
        textField.font = NSFont.boldSystemFont(ofSize: 16)
        addSubview(button)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        textField.translatesAutoresizingMaskIntoConstraints = false
        button.translatesAutoresizingMaskIntoConstraints = false
        
        let views = ["im":imageView, "tf":textField, "bt":button] as [String:Any]
        let metrics = ["lsps":10, "imh":80, "imw":300, "btw":80, "bth":20] as [String : NSNumber]
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-lsps-[im(imw)]-lsps-|", options: [], metrics: metrics, views: views))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-lsps-[tf]-[bt(btw)]-lsps-|", options: [.alignAllCenterY], metrics: metrics, views: views))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-lsps-[im(imh)]-[tf(bth)]-lsps-|", options: [], metrics: metrics, views: views))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[bt(bth)]", options: [], metrics: metrics, views: views))
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //MARK: - IBAction
    @objc func tap(sender: Any) {
        if let s = sender as? NSView {
            switch s {
            case button:
                tap?(textField.stringValue)
                break
            default:
                break
            }
        }   else if let s = (sender as? NSGestureRecognizer)?.view {
            switch s {
            case imageView:
                reloadImage?(imageView)
                break
            default:
                break
            }
        }
    }
}
