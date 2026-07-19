import Foundation

enum DrawingValidation: Equatable, Sendable {
    case accepted
    case rejected(reason: String)
}

@MainActor
struct DrawingChallengeSystem {
    let catalog: CoreMLLabelCatalog

    func prepareLabels(for chapter: StoryChapter, state: inout StoryState) {
        let definitions = StoryConfiguration.challenges(for: chapter)
        guard !definitions.isEmpty else { return }

        if let stored = state.chapterChallengeSelections[chapter],
           isValid(stored, expectedCount: definitions.count) {
            apply(stored, to: definitions, state: &state)
            return
        }

        let legacySelections = definitions.compactMap { definition -> DrawingChallengeSelection? in
            guard let label = state.selectedChallengeLabels[definition.id],
                  catalog.contains(label, in: definition.category) else { return nil }
            return DrawingChallengeSelection(id: UUID(), category: definition.category, label: label)
        }
        if legacySelections.count == definitions.count {
            state.chapterChallengeSelections[chapter] = legacySelections
            apply(legacySelections, to: definitions, state: &state)
            return
        }

        do {
            let seed = state.storyRandomSeed
                &+ UInt64(chapter.order + 1) &* 0x9E37_79B9_7F4A_7C15
            let selections = try DrawingChallengeRandomizer(catalog: catalog)
                .generateChallenges(for: chapter, seed: seed)
            state.chapterChallengeSelections[chapter] = selections
            apply(selections, to: definitions, state: &state)
        } catch {
            print("[DrawingChallengeRandomizer] \(error.localizedDescription)")
        }
    }

    func resetChallenges(
        for chapter: StoryChapter,
        seed: UInt64? = nil,
        state: inout StoryState
    ) throws {
        let definitions = StoryConfiguration.challenges(for: chapter)
        guard !definitions.isEmpty else {
            throw DrawingChallengeRandomizerError.unsupportedChapter(chapter)
        }
        state.chapterChallengeSelections[chapter] = nil
        definitions.forEach { state.selectedChallengeLabels[$0.id] = nil }
        let selections = try DrawingChallengeRandomizer(catalog: catalog)
            .generateChallenges(for: chapter, seed: seed)
        state.chapterChallengeSelections[chapter] = selections
        apply(selections, to: definitions, state: &state)
    }

    func validate(_ result: RecognitionResult, for definition: DrawingMissionDefinition, expectedLabel: String) -> DrawingValidation {
        guard normalize(result.label) == normalize(expectedLabel) else {
            return .rejected(reason: "Drawing not recognized. Try again.")
        }
        guard result.confidence >= definition.confidenceThreshold else {
            return .rejected(reason: "Drawing confidence is too low. Try again.")
        }
        return .accepted
    }

    private func normalize(_ value: String) -> String {
        value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func apply(
        _ selections: [DrawingChallengeSelection],
        to definitions: [DrawingMissionDefinition],
        state: inout StoryState
    ) {
        definitions.forEach { state.selectedChallengeLabels[$0.id] = nil }
        for (definition, selection) in zip(definitions, selections) {
            state.selectedChallengeLabels[definition.id] = selection.label
        }
    }

    private func isValid(_ selections: [DrawingChallengeSelection], expectedCount: Int) -> Bool {
        guard selections.count == expectedCount,
              Set(selections.map(\.label)).count == selections.count else { return false }
        return selections.allSatisfy {
            catalog.availableLabels.contains($0.label) && catalog.contains($0.label, in: $0.category)
        }
    }
}
