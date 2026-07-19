import CoreML
import Testing
@testable import GameClassification

@Suite("Core ML label compatibility")
@MainActor
struct CoreMLLabelCompatibilityTests {
    @Test("Every configured category and Kitchen prompt intersects the 159-label model")
    func categoriesUseExactModelLabels() throws {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .cpuOnly
        let model = try SketchClassifierV3(configuration: configuration)
        let modelLabels = Set((model.model.modelDescription.classLabels ?? []).compactMap { $0 as? String })
        let catalog = CoreMLLabelCatalog(availableLabels: modelLabels)

        #expect(modelLabels.count == 159)
        for definition in StoryConfiguration.challenges {
            #expect(!catalog.labels(in: definition.category).isEmpty)
            #expect(catalog.labels(in: definition.category).allSatisfy(modelLabels.contains))
        }
        #expect(!catalog.labels(in: .food).isEmpty)
        #expect(catalog.labels(in: .food).allSatisfy(modelLabels.contains))
    }

    @Test("Cockpit materializes moon, sun, and ufo exactly once")
    func cockpitLabels() {
        var state = StoryState.initial
        state.currentChapter = .cockpit
        state.completedChallengeIDs = Set(
            StoryConfiguration.laboratoryChallenges.map(\.id)
                + StoryConfiguration.engineInitialChallenges.map(\.id)
                + StoryConfiguration.storageChallenges.map(\.id)
                + StoryConfiguration.engineFinalChallenges.map(\.id)
        )
        let system = StoryProgressionSystem(state: state)
        let labels = StoryConfiguration.cockpitChallenges.compactMap { system.state.selectedChallengeLabels[$0.id] }

        #expect(Set(labels) == Set(["moon", "sun", "ufo"]))
        #expect(labels.count == 3)
        #expect(Set(labels).count == 3)
    }

    @Test("Album retains the verified 157 references")
    func albumReferenceCount() {
        #expect(AlbumBookViewModel.allLabels.count == 157)
        #expect(Set(AlbumBookViewModel.allLabels).count == 157)
    }
}
