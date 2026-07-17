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
        let model = try SketchClassifierV3(configuration: configuration)
        let modelLabels = Set((model.model.modelDescription.classLabels ?? []).compactMap { $0 as? String })
        
        let storyLabels = StoryContent.objectives.flatMap { objective -> [String] in
            switch objective.kind {
            case let .drawing(prompt):
                return [prompt.expectedLabel]
            case let .easel(easelDef):
                return easelDef.pool.map(\.expectedLabel)
            default:
                return []
            }
        }
        let kitchenLabels = DrawingChallenge.foodPool.map(\.label)

        #expect(modelLabels.count == 172)
        #expect((storyLabels + kitchenLabels).allSatisfy(modelLabels.contains))
    }

    @Test("Cockpit easel contains moon, sun, and ufo")
    func cockpitEaselContainsMoonSunUfo() throws {
        let objective = try #require(StoryContent.definition(id: "cockpit-easel"))
        let kind = objective.kind
        guard case let .easel(easelDef) = kind else {
            Issue.record("Cockpit easel must remain an easel objective")
            return
        }

        let labels = easelDef.pool.map(\.expectedLabel)
        #expect(labels == ["moon", "sun", "ufo"])
    }
}
