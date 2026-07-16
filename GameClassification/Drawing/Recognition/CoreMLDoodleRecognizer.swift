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
    private var model: HandwritingGameClassificationV2?

    func recognize(_ drawing: PKDrawing) async throws -> RecognitionResult {
        guard !drawing.bounds.isEmpty else {
            throw DoodleRecognitionError.emptyDrawing
        }
        
        let padding: CGFloat = 24
        let sourceBounds = drawing.bounds.insetBy(dx: -padding, dy: -padding)
        let renderedImage = drawing.image(from: sourceBounds, scale: 1.0)
        
        // Debug Langkah 3: Print ukuran UIImage dan coba simpan ke Photos
        print("--- DEBUG PENCILKIT ---")
        print("Rendered Image Size:", renderedImage.size)
        DispatchQueue.main.async {
            UIImageWriteToSavedPhotosAlbum(renderedImage, nil, nil, nil)
        }
        
        let model = try cachedModel()
        let visionModel = try VNCoreMLModel(for: model.model)
        
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
            
            request.imageCropAndScaleOption = .centerCrop
            
            guard let cgImage = renderedImage.cgImage else {
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

    private func cachedModel() throws -> HandwritingGameClassificationV2 {
        if let model { return model }
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        let model = try HandwritingGameClassificationV2(configuration: configuration)
        self.model = model
        return model
    }
}
