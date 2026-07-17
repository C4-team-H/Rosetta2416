import CoreML
import Foundation
import PencilKit
import Vision
import UIKit

enum DoodleRecognitionError: LocalizedError {
    case emptyDrawing

    var errorDescription: String? {
        switch self {
        case .emptyDrawing: "The drawing is empty."
        }
    }
}

actor CoreMLDoodleRecognizer: DoodleRecognizer {
    private var runner: GeneratedDoodleModelRunner?

    func recognize(_ drawing: PKDrawing) async throws -> RecognitionResult {
        let runner = await cachedRunner()
        return try await runner.recognize(drawing)
    }

    private func cachedRunner() async -> GeneratedDoodleModelRunner {
        if let runner { return runner }
        let runner = await GeneratedDoodleModelRunner()
        self.runner = runner
        return runner
    }
}

/// The generated Core ML wrapper is main-actor isolated by this target's
/// concurrency settings. This runner owns and reuses exactly one wrapper while
/// the recognizer actor serializes all requests made to it.
@MainActor
private final class GeneratedDoodleModelRunner {
    private var model: SketchClassifierV3?
    private var visionModel: VNCoreMLModel?

    private var debugCounter = 0

    func recognize(_ drawing: PKDrawing) async throws -> RecognitionResult {
        guard !drawing.bounds.isEmpty else {
            throw DoodleRecognitionError.emptyDrawing
        }

        // ── DEBUG: log drawing info ──────────────────────────────
        debugCounter += 1
        let seq = debugCounter
        print("[DEBUG \(seq)] strokes: \(drawing.strokes.count), bounds: \(drawing.bounds)")
        
        let padding: CGFloat = 24
        let sourceBounds = drawing.bounds.insetBy(dx: -padding, dy: -padding)
        
        let scale: CGFloat = {
            let activeScene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
            return activeScene?.screen.scale ?? 2.0
        }()
        
        var rawImage: UIImage!
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            rawImage = drawing.image(from: sourceBounds, scale: scale)
        }

        // ── DEBUG: log raw image ─────────────────────────────────
        print("[DEBUG \(seq)] rawImage size: \(rawImage.size), scale: \(rawImage.scale)")

        // Model was trained on BGR 360x360 pixels.
        let targetSize = CGSize(width: 360, height: 360)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0   // output persis 360x360 px
        format.opaque = true // tidak perlu alpha channel
        let whiteImage: UIImage = UIGraphicsImageRenderer(size: targetSize, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: targetSize))
            rawImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        // ── DEBUG: save composite to Documents for visual inspection ──
        if let pngData = whiteImage.pngData() {
            let hash = pngData.hashValue
            print("[DEBUG \(seq)] whiteImage PNG bytes: \(pngData.count), hash: \(hash)")
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let url = docs.appendingPathComponent("debug_drawing_\(seq).png")
            try? pngData.write(to: url)
            print("[DEBUG \(seq)] saved to: \(url.path)")
        }
        if let cg = whiteImage.cgImage {
            print("[DEBUG \(seq)] cgImage: \(cg.width)×\(cg.height) px")
        }

        let visionModel = try cachedVisionModel()
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: visionModel) { request, error in
                // Debug Langkah 1: Log Vision error paling atas
                if let error = error {
                    print("Vision error:", error)
                    continuation.resume(throwing: error)
                    return
                }
                
                // Debug Langkah 2: Log observations count & confidence
                let results = request.results
                print("Vision results count:", results?.count ?? 0)
                
                guard let classificationResults = results as? [VNClassificationObservation] else {
                    print("Vision warning: Results are not VNClassificationObservations")
                    continuation.resume(returning: RecognitionResult(label: "", confidence: 0.0, alternatives: []))
                    return
                }
                
                for (index, observation) in classificationResults.prefix(10).enumerated() {
                    print("Observation [\(index)] label: \(observation.identifier), confidence: \(observation.confidence)")
                }
                
                guard let topCandidate = classificationResults.first else {
                    continuation.resume(returning: RecognitionResult(label: "", confidence: 0.0, alternatives: []))
                    return
                }
                
                let candidates = classificationResults.prefix(5).map {
                    RecognitionCandidate(label: $0.identifier, confidence: Double($0.confidence))
                }
                
                continuation.resume(returning: RecognitionResult(
                    label: topCandidate.identifier.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
                    confidence: Double(topCandidate.confidence),
                    alternatives: candidates
                ))
            }
            
            request.imageCropAndScaleOption = .scaleFit
            
            guard let cgImage = whiteImage.cgImage else {
                continuation.resume(throwing: DoodleRecognitionError.emptyDrawing)
                return
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("Vision perform error:", error)
                continuation.resume(throwing: error)
            }
        }
    }

    private func cachedVisionModel() throws -> VNCoreMLModel {
        if let visionModel { return visionModel }
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .cpuAndGPU
        let model = try SketchClassifierV3(configuration: configuration)
        self.model = model
        let visionModel = try VNCoreMLModel(for: model.model)
        self.visionModel = visionModel
        return visionModel
    }
}
