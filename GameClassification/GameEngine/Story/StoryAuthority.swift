import Foundation
import PencilKit

struct StoryAuthorityResult: Sendable {
    let accepted: Bool
    let message: String
    let effects: [StoryEffect]
    let recognition: RecognitionResult?
}

@MainActor
protocol StoryAuthority: AnyObject {
    func execute(_ command: StoryCommand) async -> StoryAuthorityResult
}

@MainActor
final class LocalStoryAuthority: StoryAuthority {
    private let sessionState: GameSessionState
    private let recognizer: DoodleRecognizer

    init(sessionState: GameSessionState, recognizer: DoodleRecognizer) {
        self.sessionState = sessionState
        self.recognizer = recognizer
    }

    func execute(_ command: StoryCommand) async -> StoryAuthorityResult {
        guard sessionState.storySystem.markCommandProcessed(id: command.id) else {
            return StoryAuthorityResult(accepted: false, message: "This request was already processed.", effects: [], recognition: nil)
        }

        switch command {
        case let .requestInteraction(_, stationID, _):
            let effects = sessionState.handle(.stationInteractionRequested(stationID))
            return StoryAuthorityResult(accepted: effects.isEmpty, message: effects.isEmpty ? "Ready" : "Unavailable", effects: effects, recognition: nil)

        case let .submitDrawing(_, objectiveID, drawingData, _):
            do {
                let drawing = try PKDrawing(data: drawingData)
                guard !drawing.strokes.isEmpty else {
                    return StoryAuthorityResult(
                        accepted: false,
                        message: "Draw something before submitting.",
                        effects: [],
                        recognition: nil
                    )
                }
                let recognition = try await recognizer.recognize(drawing)

                if objectiveID.hasPrefix("kitchen-") {
                    let expectedLabel = String(objectiveID.dropFirst("kitchen-".count))
                    guard sessionState.storySystem.labelCatalog.contains(expectedLabel, in: .food),
                          normalize(recognition.label) == normalize(expectedLabel),
                          recognition.confidence >= 0.50 else {
                        let effects = sessionState.handle(.drawingFailed(objectiveID: objectiveID))
                        return StoryAuthorityResult(accepted: false, message: "Food drawing not recognized. Try again.", effects: effects, recognition: recognition)
                    }
                    _ = sessionState.handle(.foodCompleted)
                    return StoryAuthorityResult(accepted: true, message: "Energy restored by 50%.", effects: [], recognition: recognition)
                }

                let effects = sessionState.handle(.drawingValidated(objectiveID: objectiveID, result: recognition))
                let accepted = effects.contains(.objectiveCompleted(objectiveID))
                return StoryAuthorityResult(
                    accepted: accepted,
                    message: accepted ? "Repair completed." : "Drawing not recognized. Try again.",
                    effects: effects,
                    recognition: recognition
                )
            } catch {
                return StoryAuthorityResult(accepted: false, message: error.localizedDescription, effects: [], recognition: nil)
            }

        case .collect:
            return StoryAuthorityResult(accepted: false, message: "Collection is not available for this item.", effects: [], recognition: nil)
        }
    }

    private func normalize(_ value: String) -> String {
        value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
