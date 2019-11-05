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
        let model = try? VNCoreMLModel(for: FourX().model)
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

//
// FourX.swift
//
// This file was automatically generated and should not be edited.
//

import CoreML


/// Model Prediction Input Type
@available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
class FourXInput : MLFeatureProvider {

    /// Input image as color (kCVPixelFormatType_32BGRA) image buffer, 224 pixels wide by 224 pixels high
    var image: CVPixelBuffer

    var featureNames: Set<String> {
        get {
            return ["image"]
        }
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        if (featureName == "image") {
            return MLFeatureValue(pixelBuffer: image)
        }
        return nil
    }
    
    init(image: CVPixelBuffer) {
        self.image = image
    }
}

/// Model Prediction Output Type
@available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
class FourXOutput : MLFeatureProvider {

    /// Source provided by CoreML

    private let provider : MLFeatureProvider


    /// Prediction probabilities as dictionary of strings to doubles
    lazy var labelProbability: [String : Double] = {
        [unowned self] in return self.provider.featureValue(for: "labelProbability")!.dictionaryValue as! [String : Double]
    }()

    /// Class label of top prediction as string value
    lazy var label: String = {
        [unowned self] in return self.provider.featureValue(for: "label")!.stringValue
    }()

    var featureNames: Set<String> {
        return self.provider.featureNames
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        return self.provider.featureValue(for: featureName)
    }

    init(labelProbability: [String : Double], label: String) {
        self.provider = try! MLDictionaryFeatureProvider(dictionary: ["labelProbability" : MLFeatureValue(dictionary: labelProbability as [AnyHashable : NSNumber]), "label" : MLFeatureValue(string: label)])
    }

    init(features: MLFeatureProvider) {
        self.provider = features
    }
}


/// Class for model loading and prediction
@available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
class FourX {
    var model: MLModel

/// URL of model assuming it was installed in the same bundle as this class
    class var urlOfModelInThisBundle : URL {
        let bundle = Bundle(for: FourX.self)
        return bundle.url(forResource: "Four", withExtension:"mlmodelc")!
    }

    /**
        Construct a model with explicit path to mlmodelc file
        - parameters:
           - url: the file url of the model
           - throws: an NSError object that describes the problem
    */
    init(contentsOf url: URL) throws {
        self.model = try MLModel(contentsOf: url)
    }

    /// Construct a model that automatically loads the model from the app's bundle
    convenience init() {
        try! self.init(contentsOf: type(of:self).urlOfModelInThisBundle)
    }

    /**
        Construct a model with configuration
        - parameters:
           - configuration: the desired model configuration
           - throws: an NSError object that describes the problem
    */
    @available(macOS 10.14, iOS 12.0, tvOS 12.0, watchOS 5.0, *)
    convenience init(configuration: MLModelConfiguration) throws {
        try self.init(contentsOf: type(of:self).urlOfModelInThisBundle, configuration: configuration)
    }

    /**
        Construct a model with explicit path to mlmodelc file and configuration
        - parameters:
           - url: the file url of the model
           - configuration: the desired model configuration
           - throws: an NSError object that describes the problem
    */
    @available(macOS 10.14, iOS 12.0, tvOS 12.0, watchOS 5.0, *)
    init(contentsOf url: URL, configuration: MLModelConfiguration) throws {
        self.model = try MLModel(contentsOf: url, configuration: configuration)
    }

    /**
        Make a prediction using the structured interface
        - parameters:
           - input: the input to the prediction as FourXInput
        - throws: an NSError object that describes the problem
        - returns: the result of the prediction as FourXOutput
    */
    func prediction(input: FourXInput) throws -> FourXOutput {
        return try self.prediction(input: input, options: MLPredictionOptions())
    }

    /**
        Make a prediction using the structured interface
        - parameters:
           - input: the input to the prediction as FourXInput
           - options: prediction options
        - throws: an NSError object that describes the problem
        - returns: the result of the prediction as FourXOutput
    */
    func prediction(input: FourXInput, options: MLPredictionOptions) throws -> FourXOutput {
        let outFeatures = try model.prediction(from: input, options:options)
        return FourXOutput(features: outFeatures)
    }

    /**
        Make a prediction using the convenience interface
        - parameters:
            - image: Input image as color (kCVPixelFormatType_32BGRA) image buffer, 224 pixels wide by 224 pixels high
        - throws: an NSError object that describes the problem
        - returns: the result of the prediction as FourXOutput
    */
    func prediction(image: CVPixelBuffer) throws -> FourXOutput {
        let input_ = FourXInput(image: image)
        return try self.prediction(input: input_)
    }

    /**
        Make a batch prediction using the structured interface
        - parameters:
           - inputs: the inputs to the prediction as [FourXInput]
           - options: prediction options
        - throws: an NSError object that describes the problem
        - returns: the result of the prediction as [FourXOutput]
    */
    @available(macOS 10.14, iOS 12.0, tvOS 12.0, watchOS 5.0, *)
    func predictions(inputs: [FourXInput], options: MLPredictionOptions = MLPredictionOptions()) throws -> [FourXOutput] {
        let batchIn = MLArrayBatchProvider(array: inputs)
        let batchOut = try model.predictions(from: batchIn, options: options)
        var results : [FourXOutput] = []
        results.reserveCapacity(inputs.count)
        for i in 0..<batchOut.count {
            let outProvider = batchOut.features(at: i)
            let result =  FourXOutput(features: outProvider)
            results.append(result)
        }
        return results
    }
}
