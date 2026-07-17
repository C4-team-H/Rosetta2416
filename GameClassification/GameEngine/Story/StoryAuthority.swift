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
                let recognition = try await recognizer.recognize(drawing)

                if objectiveID.hasPrefix("kitchen-") {
                    guard let challenge = DrawingChallenge.foodPool.first(where: { $0.id == objectiveID }),
                          normalize(recognition.label) == normalize(challenge.label) else {
                        return StoryAuthorityResult(accepted: false, message: "Food drawing not recognized. Try again.", effects: [], recognition: recognition)
                    }
                    sessionState.storySystem.markKitchenLabelCompleted(challenge.label)
                    _ = sessionState.handle(.foodCompleted)
                    return StoryAuthorityResult(accepted: true, message: "Energy restored by 40%.", effects: [], recognition: recognition)
                }

                let effects = sessionState.handle(.drawingValidated(objectiveID: objectiveID, result: recognition))
                let accepted = effects.contains { effect in
                    if case .objectiveCompleted(objectiveID) = effect { return true }
                    // For easel partial completions, check mapNeedsRefresh as an indicator
                    if case .mapNeedsRefresh = effect { return true }
                    return false
                }
                // Easel partial completion is also accepted
                let isEaselPartial: Bool = {
                    guard let def = sessionState.storySystem.definition(id: objectiveID),
                          case .easel = def.kind else { return false }
                    return !effects.contains { if case .interactionDenied = $0 { return true }; return false }
                }()
                let finalAccepted = accepted || isEaselPartial
                return StoryAuthorityResult(
                    accepted: finalAccepted,
                    message: finalAccepted ? "Repair completed." : "Drawing not recognized. Try again.",
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
