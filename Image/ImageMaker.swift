//
//  ImageMaker.swift
//  WebShell
//
//  Created by virus1993 on 2018/2/28.
//  Copyright © 2018年 ascp. All rights reserved.
//

#if os(macOS)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

#if os(macOS)
    
#elseif os(iOS)
    
#endif

class ImageMaker {
#if os(macOS)
    public var shareImage : NSImage?
    static func read(imageName: String) -> NSImage? {
        return NSImage(named: NSImage.Name(imageName))
    }
    
#elseif os(iOS)
    public var shareImage : UIImage?
    static func read(imageName: String) -> UIImage? {
        return UIImage(named: imageName)
    }
#endif
    
    init(name: String?) {
        guard let n = name else { return }
        shareImage = ImageMaker.read(imageName: n)
    }
    
    init(data: Data) {
        #if os(macOS)
            shareImage = NSImage(data: data)
        #elseif os(iOS)
            shareImage = UIImage(data: data)
        #endif
    }
    
#if os(macOS)
    func convertGraySpace() -> NSImage? {
        guard let cgImage = self.shareImage?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("CGImage Create Failed!")
            return nil
        }
        guard let cgImage2 = _convertGraySpace(cgImage: cgImage, size: self.shareImage!.size) else {
            print("Convert Gray Space Failed!")
            return nil
        }
        return NSImage(cgImage: cgImage2, size: self.shareImage!.size)
    }
#elseif os(iOS)
    func convertGraySpace() -> UIImage? {
        guard let cgImage = self.shareImage?.cgImage else {
            print("CGImage Create Failed!")
            return nil
        }
        guard let cgImage2 = _convertGraySpace(cgImage: cgImage, size: self.shareImage!.size) else {
            print("Convert Gray Space Failed!")
            return nil
        }
        return UIImage(cgImage: cgImage2)
    }
#endif
    
    
    func _convertGraySpace(cgImage: CGImage, size: CGSize) -> CGImage? {
        let width = size.width
        let height = size.height
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo.init(rawValue: CGImageAlphaInfo.none.rawValue)
        guard let context = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else {
            print("Context Create Failed！")
            return nil
        }
        
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        
        context.draw(cgImage, in: rect)
        
        if let newCGImage = context.makeImage() {
            return newCGImage
        }
        
        return nil
    }

#if os(macOS)
    func crop4Images() -> (CGImage, CGImage, CGImage, CGImage)? {
        guard let cgImageX = self.shareImage?.cgImage(forProposedRect: nil, context: nil, hints: nil)   else    {
            return nil
        }
        return _crop4Images(cgImage: cgImageX)
    }
#elseif os(iOS)
    func crop4Images() -> (CGImage, CGImage, CGImage, CGImage)? {
        guard let cgImageX = self.shareImage?.cgImage   else    {
            return nil
        }
        return _crop4Images(cgImage: cgImageX)
    }
#endif
    
    func _crop4Images(cgImage: CGImage) -> (CGImage, CGImage, CGImage, CGImage) {
        let w = [70, 65, 65, 70]
        let h = 80
        let y = 0
        let x = [35, 95, 155, 210]
        //        let w = [75, 60, 60, 75]
        //        let h = 80
        //        let y = 0
        //        let x = [30, 95, 150, 207]
        
        var array = [CGImage]()
        let cgImageX = cgImage
        for i in 0...3 {
            let width = w[i]
            let ox = x[i]
            let size = CGSize(width: width, height: h)
            let origin = CGPoint(x: ox, y: y)
            let cropImage = cgImageX.cropping(to: CGRect(origin: origin, size: size))!
            let img = cropImage
            array.append(img)
        }
        
        array = array.map { $0.scale(toSise: CGSize(width: 224, height: 224)) }
        
        return (array[0], array[1], array[2], array[3])
    }
    
#if os(macOS)
    func convertBlackWhite() -> CGImage? {
        guard let cgImage = self.shareImage?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("CGImage Create Failed!")
            return nil
        }
        return _convertBlackWhite(cgImage: cgImage)
    }
#elseif os(iOS)
    func convertBlackWhite() -> CGImage? {
        guard let cgImage = self.shareImage?.cgImage else {
            print("CGImage Create Failed!")
            return nil
        }
        return _convertBlackWhite(cgImage: cgImage)
    }
#endif
    
    func _convertBlackWhite(cgImage: CGImage) -> CGImage? {
        let width = 300
        let height = 80
        let mnutableData = CFDataCreateMutableCopy(nil, cgImage.width * cgImage.bytesPerRow * cgImage.height, cgImage.dataProvider!.data)
        let bitmapDataPtr = CFDataGetMutableBytePtr(mnutableData)!
        
        for row in 0..<cgImage.height {
            for col in 0..<cgImage.width {
                let pixel = bitmapDataPtr + (row * cgImage.bytesPerRow + col * cgImage.bitsPerPixel / cgImage.bitsPerComponent)
                pixel[0] = (pixel[0] >= 160) ? 0:255
            }
        }
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        
        let hightPassData = CGDataProvider(data: mnutableData!)
        let cgPower = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: 300, space: colorSpace, bitmapInfo: bitmapInfo, provider: hightPassData!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        return cgPower
    }
}
