//
//  VCMLParser.swift
//  WebShell
//
//  Created by virus1993 on 2018/2/28.
//  Copyright © 2018年 ascp. All rights reserved.
//

import AppKit
import Vision

struct CodeLabel {
    var first : String
    var second : String
    var third : String
    var four : String
    var images : (CGImage, CGImage, CGImage, CGImage)
    init(images: (CGImage, CGImage, CGImage, CGImage)) {
        first = ""
        second = ""
        third = ""
        four = ""
        self.images = images
    }
}

typealias AILabelsCallBack = ((CodeLabel)->())?

class AIBot {
    private static let _share = AIBot()
    static var share : AIBot {
        return _share
    }
    var originImage : NSImage?
    typealias FoundLabelCallBack = ((String)->())?
    
    func makeImage(completion: AILabelsCallBack) {
        if let image = originImage {
            let imgs = image.crop4Images()
            DispatchQueue.global(qos: .userInitiated).async {
                [unowned self] in
                var labels = CodeLabel(images: imgs)
                self.parser(image: imgs.0, message: "--- 第1位 ---", callback: { label in
                    labels.first = label
                })
                self.parser(image: imgs.1, message: "--- 第2位 ---", callback: { label in
                    labels.second = label
                })
                self.parser(image: imgs.2, message: "--- 第3位 ---", callback: { label in
                    labels.third = label
                })
                self.parser(image: imgs.3, message: "--- 第4位 ---", callback: { label in
                    labels.four = label
                    completion?(labels)
                })
            }
        }
    }
    
    func parser(image: CGImage, message: String, callback: FoundLabelCallBack) {
        let handler = VNImageRequestHandler(cgImage: image)
        print(message)
        do {
            try handler.perform([classificationRequest(callback: callback)])
        } catch {
            /*
             This handler catches general image processing errors. The `classificationRequest`'s
             completion handler `processClassifications(_:error:)` catches errors specific
             to processing that request.
             */
            print("Failed to perform classification.\n\(error.localizedDescription)")
        }
    }
    
    func classificationRequest(callback: FoundLabelCallBack) -> VNCoreMLRequest {
        let model = try? VNCoreMLModel(for: Four().model)
        let request = VNCoreMLRequest(model: model!, completionHandler: { req, error in
            guard let results = req.results else {
                print("Unable to classify image.\n\(error!.localizedDescription)")
                return
            }
            // The `results` will always be `VNClassificationObservation`s, as specified by the Core ML model in this project.
            let classifications = results as! [VNClassificationObservation]
//            classifications.forEach({ print("pi: \($0.confidence), label: \($0.identifier)") })
            print("label: \(classifications.first?.identifier ?? "none"), confidence: \(classifications.first?.confidence ?? 0.0)")
            callback?(classifications.first?.identifier ?? "none")
            if classifications.count <= 0 {
                print("识别结果为空")
            }
        })
        request.imageCropAndScaleOption = .scaleFill
        
//        #if TARGET_OS_OSX
//        request.usesCPUOnly = true
//        #elseif TARGET_OS_IOS
//        request.usesCPUOnly = false
//        #endif
        request.usesCPUOnly = true
        
        return request
    }
    
    //MARK: - Parser Function
    static func recognize(codeImage: NSImage?, completion: AILabelsCallBack) {
        guard let img = codeImage else {
            print("$$$$$ no code image! $$$$$")
            return
        }
        let bot = AIBot.share
        bot.originImage = img
        bot.makeImage(completion: completion)
    }
}

extension NSImage {
    func convertRGBSpace() -> NSImage? {
        let width = size.width
        let height = size.height
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        guard let context = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else {
            print("Context Create Failed！")
            return nil
        }
        
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("CGImage Create Failed!")
            return nil
        }
        
        context.draw(cgImage, in: rect)
        
        if let newCGImage = context.makeImage() {
            return NSImage(cgImage: newCGImage, size: rect.size)
        }
        
        return nil
    }
    
    func convertGraySpace() -> NSImage? {
        let width = size.width
        let height = size.height
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo.init(rawValue: CGImageAlphaInfo.none.rawValue)
        guard let context = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else {
            print("Context Create Failed！")
            return nil
        }
        
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("CGImage Create Failed!")
            return nil
        }
        
        context.draw(cgImage, in: rect)
        
        if let newCGImage = context.makeImage() {
            return NSImage(cgImage: newCGImage, size: rect.size)
        }
        
        return nil
    }
    
    func crop4Images() -> (CGImage, CGImage, CGImage, CGImage) {
        let w = [70, 65, 65, 70]
        let h = 80
        let y = 0
        let x = [35, 95, 155, 210]
        //        let w = [75, 60, 60, 75]
        //        let h = 80
        //        let y = 0
        //        let x = [30, 95, 150, 207]
        
        var array = [CGImage]()
        let cgImageX = cgImage(forProposedRect: nil, context: nil, hints: nil)
        for i in 0...3 {
            let width = w[i]
            let ox = x[i]
            let size = CGSize(width: width, height: h)
            let origin = CGPoint(x: ox, y: y)
            let cropImage = cgImageX!.cropping(to: CGRect(origin: origin, size: size))!
            let img = cropImage
            array.append(img)
        }
        
        array = array.map { $0.scale(toSise: CGSize(width: 224, height: 224)) }
        
        return (array[0], array[1], array[2], array[3])
    }
    
    func convertBlackWhite() -> CGImage? {
        let width = 300
        let height = 80
        
        //width = 300, height = 80, bpc = 8, bpp = 8, row bytes = 300
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("CGImage Create Failed!")
            return nil
        }
        
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

extension CGImage {
    func scale(toSise: CGSize) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.init(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)
        let context = CGContext(data: nil, width: Int(toSise.width), height: Int(toSise.height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
        context?.draw(self, in: CGRect(origin: CGPoint.init(x: 0, y: 0), size: toSise))
        return context!.makeImage()!
    }
}

