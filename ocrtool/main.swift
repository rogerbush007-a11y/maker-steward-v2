#!/usr/bin/env swift

import Foundation
import Vision
import AppKit

// 从命令行参数获取图片路径
let arguments = CommandLine.arguments
guard arguments.count > 1 else {
    print("{\"error\": \"请提供图片路径\"}")
    exit(1)
}

let imagePath = arguments[1]
let imageURL = URL(fileURLWithPath: imagePath)

guard let imageData = try? Data(contentsOf: imageURL),
      let nsImage = NSImage(data: imageData) else {
    print("{\"error\": \"无法读取图片: \(imagePath)\"}")
    exit(1)
}

let semaphore = DispatchSemaphore(value: 0)
var resultText = ""
var errorMsg = ""

let request = VNRecognizeTextRequest { request, error in
    if let error = error {
        errorMsg = error.localizedDescription
        semaphore.signal()
        return
    }
    guard let observations = request.results as? [VNRecognizedTextObservation] else {
        errorMsg = "未能识别到文字"
        semaphore.signal()
        return
    }
    let texts = observations.compactMap { $0.topCandidates(1).first?.string }
    resultText = texts.joined(separator: "\n")
    semaphore.signal()
}

request.recognitionLevel = .fast
request.recognitionLanguages = ["zh-Hans", "en-US"]
request.usesLanguageCorrection = true

// 尝试多种初始化方式
func tryOCR() -> Bool {
    // 方式1: Data
    if let handler = try? VNImageRequestHandler(data: imageData, options: [:]),
       let _ = try? handler.perform([request]) {
        semaphore.wait()
        return true
    }

    // 方式2: CGImage
    if let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
        // 缩小图片到合理大小
        var processImage = nsImage
        let maxDim: CGFloat = 1280
        if nsImage.size.width > maxDim || nsImage.size.height > maxDim {
            let scale = min(maxDim / nsImage.size.width, maxDim / nsImage.size.height)
            let newSize = NSSize(width: nsImage.size.width * scale, height: nsImage.size.height * scale)
            processImage = NSImage(size: newSize)
            processImage.lockFocus()
            nsImage.draw(in: NSRect(origin: .zero, size: newSize))
            processImage.unlockFocus()
        }
        if let resizedCG = processImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let handler = VNImageRequestHandler(cgImage: resizedCG, options: [:])
            if let _ = try? handler.perform([request]) {
                semaphore.wait()
                return true
            }
        }

        // 方式3: 原图
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        if let _ = try? handler.perform([request]) {
            semaphore.wait()
            return true
        }
    }

    return false
}

if !tryOCR() {
    print("{\"error\": \"OCR 识别失败\"}")
    exit(1)
}

if !errorMsg.isEmpty {
    print("{\"error\": \"\(errorMsg)\"}")
    exit(1)
}

// 输出 JSON
let escaped = resultText
    .replacingOccurrences(of: "\\", with: "\\\\")
    .replacingOccurrences(of: "\"", with: "\\\"")
    .replacingOccurrences(of: "\n", with: "\\n")
    .replacingOccurrences(of: "\r", with: "\\r")
print("{\"text\": \"\(escaped)\"}")
