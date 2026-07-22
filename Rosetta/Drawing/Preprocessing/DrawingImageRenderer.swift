import CoreGraphics
import CoreVideo
import PencilKit
import UIKit

enum DrawingImageRenderer {
    static let inputSize = CGSize(width: 360, height: 360)

    static func pixelBuffer(from drawing: PKDrawing, padding: CGFloat = 24) -> CVPixelBuffer? {
        guard !drawing.bounds.isEmpty else { return nil }
        let sourceBounds = drawing.bounds.insetBy(dx: -padding, dy: -padding)
        let rendered = drawing.image(from: sourceBounds, scale: 1)

        let renderer = UIGraphicsImageRenderer(size: inputSize)
        let normalized = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: inputSize))

            let scale = min(inputSize.width / rendered.size.width, inputSize.height / rendered.size.height)
            let size = CGSize(width: rendered.size.width * scale, height: rendered.size.height * scale)
            let origin = CGPoint(x: (inputSize.width - size.width) / 2, y: (inputSize.height - size.height) / 2)
            rendered.draw(in: CGRect(origin: origin, size: size))
        }

        guard let cgImage = normalized.cgImage else { return nil }
        return makePixelBuffer(from: cgImage)
    }

    private static func makePixelBuffer(from image: CGImage) -> CVPixelBuffer? {
        let width = Int(inputSize.width)
        let height = Int(inputSize.height)
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelBuffer
    }
}

