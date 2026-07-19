import Foundation
import Testing
@testable import GameClassification

@Suite("Drawing challenge randomizer")
@MainActor
struct DrawingChallengeRandomizerTests {
    private var catalog: CoreMLLabelCatalog {
        CoreMLLabelCatalog(availableLabels: Set(CoreMLLabelCatalog.categoryLabels.values.flatMap { $0 }))
    }

    @Test("Laboratory selects one animal, plant, and human in shuffled order")
    func laboratoryQuotas() throws {
        let selector = DrawingChallengeRandomizer(catalog: catalog)
        let selections = try selector.generateChallenges(for: .laboratory, seed: 10)

        #expect(selections.count == 3)
        #expect(categoryCounts(selections) == [.animal: 1, .plant: 1, .human: 1])
        expectUniqueCatalogLabels(selections, catalog: selector.catalog)
    }

    @Test("Engine Initial selects two unique labels from every required category")
    func engineInitialQuotas() throws {
        let selector = DrawingChallengeRandomizer(catalog: catalog)
        let selections = try selector.generateChallenges(for: .engineInitial, seed: 20)

        #expect(selections.count == 6)
        #expect(categoryCounts(selections) == [.landscape: 2, .transportation: 2, .otherObject: 2])
        expectUniqueCatalogLabels(selections, catalog: selector.catalog)
    }

    @Test("Storage selects one tool, equipment, and furniture")
    func storageQuotas() throws {
        let selector = DrawingChallengeRandomizer(catalog: catalog)
        let selections = try selector.generateChallenges(for: .storage, seed: 30)

        #expect(selections.count == 3)
        #expect(categoryCounts(selections) == [.tool: 1, .equipment: 1, .furniture: 1])
        expectUniqueCatalogLabels(selections, catalog: selector.catalog)
    }

    @Test("Engine Final selects three electronics and cannon once")
    func engineFinalQuotas() throws {
        let selector = DrawingChallengeRandomizer(catalog: catalog)
        let selections = try selector.generateChallenges(for: .engineFinal, seed: 40)

        #expect(selections.count == 4)
        #expect(categoryCounts(selections) == [.electronics: 3, .weapon: 1])
        #expect(selections.filter { $0.category == .weapon }.map(\.label) == ["cannon"])
        expectUniqueCatalogLabels(selections, catalog: selector.catalog)
    }

    @Test("Cockpit uses moon, sun, and ufo in a shuffled order")
    func cockpitLabels() throws {
        let selector = DrawingChallengeRandomizer(catalog: catalog)
        let selections = try selector.generateChallenges(for: .cockpit, seed: 50)

        #expect(selections.count == 3)
        #expect(Set(selections.map(\.label)) == Set(["moon", "sun", "ufo"]))
        #expect(selections.allSatisfy { $0.category == .celestial })
        expectUniqueCatalogLabels(selections, catalog: selector.catalog)
    }

    @Test("Seeded generation is reproducible while different seeds vary order")
    func seededGeneration() throws {
        let selector = DrawingChallengeRandomizer(catalog: catalog)
        let first = try selector.generateChallenges(for: .engineInitial, seed: 8675309)
        let restored = try selector.generateChallenges(for: .engineInitial, seed: 8675309)
        let variants = try (1...16).map {
            try selector.generateChallenges(for: .engineInitial, seed: UInt64($0)).map(\.category)
        }
        let labelVariants = try (1...16).map {
            try selector.generateChallenges(for: .laboratory, seed: UInt64($0)).map(\.label)
        }
        let cockpitOrders = try (1...16).map {
            try selector.generateChallenges(for: .cockpit, seed: UInt64($0)).map(\.label)
        }

        #expect(first == restored)
        #expect(Set(variants).count > 1)
        #expect(Set(labelVariants).count > 1)
        #expect(Set(cockpitOrders).count > 1)
    }

    @Test("Category order is not permanently fixed for any multi-category chapter")
    func shuffledCategoryOrder() throws {
        let selector = DrawingChallengeRandomizer(catalog: catalog)
        for chapter in [StoryChapter.laboratory, .engineInitial, .storage, .engineFinal] {
            let orders = try (1...20).map { seed in
                try selector.generateChallenges(for: chapter, seed: UInt64(seed)).map(\.category)
            }
            #expect(Set(orders).count > 1)
        }
    }

    @Test("Prepared chapter selections persist and explicit reset replaces them")
    func persistenceAndReset() throws {
        let challengeSystem = DrawingChallengeSystem(catalog: catalog)
        var state = StoryState.initial
        state.currentChapter = .laboratory
        state.storyRandomSeed = 1234

        challengeSystem.prepareLabels(for: .laboratory, state: &state)
        let original = try #require(state.chapterChallengeSelections[.laboratory])
        let originalLabels = state.selectedChallengeLabels

        challengeSystem.prepareLabels(for: .laboratory, state: &state)
        #expect(state.chapterChallengeSelections[.laboratory] == original)
        #expect(state.selectedChallengeLabels == originalLabels)

        let restoredState = try JSONDecoder().decode(StoryState.self, from: JSONEncoder().encode(state))
        var restored = restoredState
        challengeSystem.prepareLabels(for: .laboratory, state: &restored)
        #expect(restored.chapterChallengeSelections[.laboratory] == original)
        #expect(restored.selectedChallengeLabels == originalLabels)

        try challengeSystem.resetChallenges(for: .laboratory, seed: 9876, state: &restored)
        #expect(restored.chapterChallengeSelections[.laboratory] != original)
    }

    @Test("Kitchen selects only food and does not immediately repeat")
    func kitchenSelection() throws {
        let selector = DrawingChallengeRandomizer(catalog: catalog)
        let first = try selector.randomFoodChallenge(excluding: nil, seed: 99)
        let second = try selector.randomFoodChallenge(excluding: first.label, seed: 99)

        #expect(first.category == .food)
        #expect(second.category == .food)
        #expect(selector.catalog.contains(first.label, in: .food))
        #expect(selector.catalog.contains(second.label, in: .food))
        #expect(second.label != first.label)
    }

    @Test("Missing and insufficient categories produce clear errors")
    func selectionErrors() {
        let missingAnimal = DrawingChallengeRandomizer(
            catalog: CoreMLLabelCatalog(availableLabels: ["tree", "hand"])
        )
        #expect(throws: DrawingChallengeRandomizerError.missingCategory(.animal)) {
            try missingAnimal.generateChallenges(for: .laboratory, seed: 1)
        }

        let insufficientElectronics = DrawingChallengeRandomizer(
            catalog: CoreMLLabelCatalog(availableLabels: ["camera", "cannon"])
        )
        #expect(throws: DrawingChallengeRandomizerError.insufficientUniqueLabels(
            category: .electronics,
            requested: 3,
            available: 1
        )) {
            try insufficientElectronics.generateChallenges(for: .engineFinal, seed: 1)
        }
    }

    private func categoryCounts(
        _ selections: [DrawingChallengeSelection]
    ) -> [DrawingCategory: Int] {
        selections.reduce(into: [:]) { counts, selection in
            counts[selection.category, default: 0] += 1
        }
    }

    private func expectUniqueCatalogLabels(
        _ selections: [DrawingChallengeSelection],
        catalog: CoreMLLabelCatalog
    ) {
        #expect(Set(selections.map(\.label)).count == selections.count)
        #expect(selections.allSatisfy { catalog.availableLabels.contains($0.label) })
        #expect(selections.allSatisfy { catalog.contains($0.label, in: $0.category) })
    }
}
