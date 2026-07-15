import CoreML
import Foundation
import PencilKit

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
        guard let pixelBuffer = DrawingImageRenderer.pixelBuffer(from: drawing) else {
            throw DoodleRecognitionError.emptyDrawing
        }
        let model = try cachedModel()
        let input = HandwritingGameClassificationV2Input(image: pixelBuffer)
        let output = try await model.prediction(input: input)
        let target = output.target
        let probabilities = output.targetProbability
        let candidates = probabilities
            .map { RecognitionCandidate(label: $0.key, confidence: $0.value) }
            .sorted { $0.confidence > $1.confidence }

        return RecognitionResult(
            label: target.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
            confidence: probabilities[target] ?? 0,
            alternatives: Array(candidates.prefix(5))
        )
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
