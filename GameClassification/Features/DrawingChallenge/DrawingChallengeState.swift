struct DrawingChallenge: Equatable, Sendable {
    let id: String
    let label: String
    let displayName: String
    let confidenceThreshold: Double

    init(id: String, label: String, displayName: String, confidenceThreshold: Double = 0.50) {
        self.id = id
        self.label = label
        self.displayName = displayName
        self.confidenceThreshold = confidenceThreshold
    }

    init(objective: StoryObjectiveDefinition) {
        guard case let .drawing(prompt) = objective.kind else {
            preconditionFailure("DrawingChallenge requires a drawing objective")
        }
        self.init(
            id: objective.id,
            label: prompt.expectedLabel,
            displayName: prompt.displayName,
            confidenceThreshold: prompt.confidenceThreshold
        )
    }

    static let foodPool: [DrawingChallenge] = [
        DrawingChallenge(id: "kitchen-banana", label: "banana", displayName: "BANANA"),
        DrawingChallenge(id: "kitchen-apple", label: "apple", displayName: "APPLE"),
        DrawingChallenge(id: "kitchen-donut", label: "donut", displayName: "DONUT"),
        DrawingChallenge(id: "kitchen-pizza", label: "pizza", displayName: "PIZZA"),
        DrawingChallenge(id: "kitchen-carrot", label: "carrot", displayName: "CARROT")
    ]
}

struct DrawingSubmissionOutcome: Sendable {
    let accepted: Bool
    let message: String
    let recognition: RecognitionResult?
}
