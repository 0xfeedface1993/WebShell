//
//  VCMLParser.swift
//  WebShell
//
//  Created by virus1993 on 2018/2/28.
//  Copyright © 2018年 ascp. All rights reserved.
//

#if TARGET_OS_MAC
    import Cocoa
    public let ImageBubble = NS
#elseif TARGET_OS_IPHONE
    import UIKit
    public let ImageBubble = UIImage()
#endif

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
    
    public var originImage : ImageMaker?
    
    typealias FoundLabelCallBack = ((String)->())?
    
    func makeImage(completion: AILabelsCallBack) {
        if let imgs = originImage?.crop4Images() {
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
        
        #if os(macOS)
            request.usesCPUOnly = true
        #elseif os(iOS)
            request.usesCPUOnly = false
        #endif
        
        return request
    }
    
    //MARK: - Parser Function
    static func recognize(codeImage: ImageMaker?, completion: AILabelsCallBack) {
        guard let img = codeImage else {
            print("$$$$$ no code image! $$$$$")
            return
        }
        let bot = AIBot.share
        bot.originImage = img
        bot.makeImage(completion: completion)
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

