import CoreML
import Testing
@testable import GameClassification

@Suite("Core ML label compatibility")
@MainActor
struct CoreMLLabelCompatibilityTests {
    @Test("Every story and Kitchen drawing prompt exists in the bundled classifier")
    func everyDrawingPromptUsesAnExactModelLabel() throws {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .cpuOnly
        let model = try HandwritingGameClassificationV2(configuration: configuration)
        let modelLabels = Set((model.model.modelDescription.classLabels ?? []).compactMap { $0 as? String })
        let storyLabels = StoryContent.objectives.compactMap { objective -> String? in
            guard case let .drawing(prompt) = objective.kind else { return nil }
            return prompt.expectedLabel
        }
        let kitchenLabels = DrawingChallenge.foodPool.map(\.label)

        #expect(modelLabels.count == 172)
        #expect((storyLabels + kitchenLabels).allSatisfy(modelLabels.contains))
    }
}
