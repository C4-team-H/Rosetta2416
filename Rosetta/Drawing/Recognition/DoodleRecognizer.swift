import Foundation
import PencilKit

struct RecognitionCandidate: Codable, Equatable, Sendable {
    let label: String
    let confidence: Double
}

struct RecognitionResult: Codable, Equatable, Sendable {
    let label: String
    let confidence: Double
    let alternatives: [RecognitionCandidate]
}

protocol DoodleRecognizer: Sendable {
    func recognize(_ drawing: PKDrawing) async throws -> RecognitionResult
}

