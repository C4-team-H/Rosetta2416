import Observation
import PencilKit

@MainActor
@Observable
final class DrawingChallengeViewModel {
    enum SubmissionState: Equatable {
        case ready
        case loading
        case accepted(String)
        case retryableError(String)
    }

    let challenge: DrawingChallenge
    private(set) var submissionState: SubmissionState = .ready
    var submissionHandler: ((PKDrawing) async -> DrawingSubmissionOutcome)?

    init(challenge: DrawingChallenge) {
        self.challenge = challenge
    }

    func submit(_ drawing: PKDrawing) async -> DrawingSubmissionOutcome {
        guard case .ready = submissionState else {
            return DrawingSubmissionOutcome(accepted: false, message: "Submission already in progress.", recognition: nil)
        }
        guard !drawing.bounds.isEmpty else {
            let message = "Draw \(challenge.displayName) before submitting."
            submissionState = .retryableError(message)
            return DrawingSubmissionOutcome(accepted: false, message: message, recognition: nil)
        }
        guard let submissionHandler else {
            let message = "Drawing challenge is not configured."
            submissionState = .retryableError(message)
            return DrawingSubmissionOutcome(accepted: false, message: message, recognition: nil)
        }

        submissionState = .loading
        let outcome = await submissionHandler(drawing)
        submissionState = outcome.accepted
            ? .accepted(outcome.message)
            : .retryableError(outcome.message)
        return outcome
    }

    func retry() {
        submissionState = .ready
    }
}

