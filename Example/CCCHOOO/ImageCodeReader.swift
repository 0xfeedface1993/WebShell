//
//  ImageCodeReader.swift
//  WebShellExsample
//
//  Created by john on 2023/9/12.
//  Copyright © 2023 ascp. All rights reserved.
//

import Foundation
import WebShell
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

enum ImageCodeReaderError: Error {
    case noImage
    case noTextFound
}

protocol ImageOberver {
    func updateImage(_ image: CGImage, tag: String) async
}

struct ImageCodeReader: CodeReadable {
    let tag: String
    let completion: @Sendable (CGImage, String) -> Void
    
    func code(_ data: Data) async throws -> String {
        try await threshold(data)
    }
    
    func threshold(_ data: Data) async throws -> String {
        // 加载输入图像
        let inputImage = CIImage(data: data)

        // 创建 CIColorThreshold 滤镜
        let colorThresholdFilter = CIFilter.colorThreshold()

        // 设置阈值
        colorThresholdFilter.inputImage = inputImage
        colorThresholdFilter.threshold = 0.2 // 阈值通常在0.0到1.0之间

        // 创建 CIColorControls 滤镜
        let colorControlsFilter = CIFilter.colorControls()

        // 设置亮度和对比度参数以进行二值化
        colorControlsFilter.inputImage = colorThresholdFilter.outputImage
        colorControlsFilter.brightness = 1.0 // 调整亮度
        colorControlsFilter.contrast = 5.0   // 调整对比度

        // 获取输出图像
        let outputImage = colorControlsFilter.outputImage

//        // 获取输出图像
//        let outputImage = colorThresholdFilter.outputImage

        // 创建 CIContext 来渲染图像
        let context = CIContext()

        // 渲染输出图像
        guard let output = outputImage, let cgImage = context.createCGImage(output, from: output.extent) else {
            throw ImageCodeReaderError.noImage
        }
        
        // Create a new image-request handler.
        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        completion(cgImage, tag)
        
        return try await requestHandler.asyncTextValue()
    }
}

extension VNImageRequestHandler {
    func asyncTextValue() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { next, error in
                if let error = error {
                    continuation.resume(with: .failure(error))
                    return
                }
                
                guard let observations = next.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: ImageCodeReaderError.noTextFound)
                    return
                }
                
                let recognizedStrings = observations.compactMap { observation in
                    // Return the string of the top VNRecognizedText instance.
                    return observation.topCandidates(1).first?.string
                }
                
                print(">>> recognize texts: \(recognizedStrings)")
                let next = recognizedStrings.joined().replacing(" ", with: "")
                print(">>> remove empty: \(next)")
                
                continuation.resume(returning: next)
            }
            
            do {
                try perform([request])
            } catch {
                continuation.resume(with: .failure(error))
            }
        }
    }
}
