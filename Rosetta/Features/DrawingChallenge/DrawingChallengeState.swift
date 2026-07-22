struct DrawingChallenge: Equatable, Sendable {
    let id: String
    let label: String
    let displayName: String
    let category: DrawingCategory
    let confidenceThreshold: Double

    init(
        id: String,
        label: String,
        displayName: String,
        category: DrawingCategory = .food,
        confidenceThreshold: Double = 0.30
    ) {
        self.id = id
        self.label = label
        self.displayName = displayName
        self.category = category
        self.confidenceThreshold = confidenceThreshold
    }

    init(objective: StoryObjectiveDefinition) {
        guard case let .drawing(prompt) = objective.kind else {
            preconditionFailure("DrawingChallenge requires a drawing objective")
        }
        let category = CoreMLLabelCatalog().category(of: prompt.expectedLabel)
            ?? StoryConfiguration.definition(id: objective.id)?.category
            ?? .otherObject
        self.init(
            id: objective.id,
            label: prompt.expectedLabel,
            displayName: prompt.displayName,
            category: category,
            confidenceThreshold: prompt.confidenceThreshold
        )
    }

    static let foodPool: [DrawingChallenge] = {
        let buah = ["apple", "banana", "grapes", "pear", "pineapple", "pumpkin", "strawberry", "tomato"]
        let makanan = ["bread", "cake", "carrot", "cone ice cream", "donut", "hamburger", "hot-dog", "mushroom", "pizza", "pretzel"]
        return (buah + makanan).map { label in
            DrawingChallenge(id: "kitchen-\(label)", label: label, displayName: label.uppercased())
        }
    }()
}

struct DrawingSubmissionOutcome: Sendable {
    let accepted: Bool
    let message: String
    let recognition: RecognitionResult?
    let hasAlbumHint: Bool

    init(accepted: Bool, message: String, recognition: RecognitionResult?, hasAlbumHint: Bool = false) {
        self.accepted = accepted
        self.message = message
        self.recognition = recognition
        self.hasAlbumHint = hasAlbumHint
    }
}
