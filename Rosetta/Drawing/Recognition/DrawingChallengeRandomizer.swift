import Foundation

struct DrawingChallengeSelection: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let category: DrawingCategory
    let label: String
}

enum DrawingChallengeRandomizerError: Error, Equatable, LocalizedError {
    case unsupportedChapter(StoryChapter)
    case missingCategory(DrawingCategory)
    case insufficientUniqueLabels(category: DrawingCategory, requested: Int, available: Int)
    case duplicateSelection(String)
    case labelMissingFromCatalog(String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedChapter(chapter):
            "No drawing challenges are configured for chapter \(chapter.rawValue)."
        case let .missingCategory(category):
            "The Core ML label catalog has no labels for category \(category.rawValue)."
        case let .insufficientUniqueLabels(category, requested, available):
            "Category \(category.rawValue) requires \(requested) unique labels, but only \(available) are available."
        case let .duplicateSelection(label):
            "Duplicate drawing label selected within one chapter: \(label)."
        case let .labelMissingFromCatalog(label):
            "Selected drawing label is not present in the Core ML label catalog: \(label)."
        }
    }
}

@MainActor
protocol DrawingChallengeRandomizing {
    func generateChallenges(
        for chapter: StoryChapter,
        seed: UInt64?
    ) throws -> [DrawingChallengeSelection]

    func randomFoodChallenge(
        excluding previousLabel: String?
    ) throws -> DrawingChallengeSelection
}

@MainActor
struct DrawingChallengeRandomizer: DrawingChallengeRandomizing {
    let catalog: CoreMLLabelCatalog

    func generateChallenges(
        for chapter: StoryChapter,
        seed: UInt64? = nil
    ) throws -> [DrawingChallengeSelection] {
        if let seed {
            var generator = SeededDrawingChallengeGenerator(seed: seed)
            return try generateChallenges(for: chapter, using: &generator)
        }
        var generator = SystemRandomNumberGenerator()
        return try generateChallenges(for: chapter, using: &generator)
    }

    func randomFoodChallenge(
        excluding previousLabel: String?
    ) throws -> DrawingChallengeSelection {
        var generator = SystemRandomNumberGenerator()
        return try randomFoodChallenge(excluding: previousLabel, using: &generator)
    }

    func randomFoodChallenge(
        excluding previousLabel: String?,
        seed: UInt64
    ) throws -> DrawingChallengeSelection {
        var generator = SeededDrawingChallengeGenerator(seed: seed)
        return try randomFoodChallenge(excluding: previousLabel, using: &generator)
    }

    func randomUniqueLabels<Generator: RandomNumberGenerator>(
        count: Int,
        from category: DrawingCategory,
        using generator: inout Generator
    ) throws -> [String] {
        try randomUniqueLabels(count: count, from: category, excluding: [], using: &generator)
    }

    func shuffledChallenges<Generator: RandomNumberGenerator>(
        categories: [DrawingCategory],
        using generator: inout Generator
    ) throws -> [DrawingChallengeSelection] {
        var usedLabels = Set<String>()
        var selections: [DrawingChallengeSelection] = []
        for category in categories {
            let labels = try randomUniqueLabels(
                count: 1,
                from: category,
                excluding: usedLabels,
                using: &generator
            )
            guard let label = labels.first else {
                throw DrawingChallengeRandomizerError.missingCategory(category)
            }
            usedLabels.insert(label)
            selections.append(selection(category: category, label: label, using: &generator))
        }
        selections.shuffle(using: &generator)
        try validate(selections)
        return selections
    }

    private func generateChallenges<Generator: RandomNumberGenerator>(
        for chapter: StoryChapter,
        using generator: inout Generator
    ) throws -> [DrawingChallengeSelection] {
        let quotas: [(DrawingCategory, Int)]
        switch chapter {
        case .laboratory:
            quotas = [(.animal, 1), (.plant, 1), (.human, 1)]
        case .engineInitial:
            quotas = [(.landscape, 2), (.transportation, 2), (.otherObject, 2)]
        case .storage:
            quotas = [(.tool, 1), (.equipment, 1), (.furniture, 1)]
        case .engineFinal:
            quotas = [(.electronics, 3), (.weapon, 1)]
        case .cockpit:
            quotas = [(.celestial, 3)]
        case .sleepingRoom, .victory:
            throw DrawingChallengeRandomizerError.unsupportedChapter(chapter)
        }

        var usedLabels = Set<String>()
        var selections: [DrawingChallengeSelection] = []
        for (category, count) in quotas {
            let labels = try randomUniqueLabels(
                count: count,
                from: category,
                excluding: usedLabels,
                using: &generator
            )
            for label in labels {
                usedLabels.insert(label)
                selections.append(selection(category: category, label: label, using: &generator))
            }
        }

        selections.shuffle(using: &generator)
        try validate(selections)
        return selections
    }

    private func randomUniqueLabels<Generator: RandomNumberGenerator>(
        count: Int,
        from category: DrawingCategory,
        excluding usedLabels: Set<String>,
        using generator: inout Generator
    ) throws -> [String] {
        var labels = catalog.labels(in: category).filter { !usedLabels.contains($0) }
        guard !labels.isEmpty else {
            throw DrawingChallengeRandomizerError.missingCategory(category)
        }
        guard labels.count >= count else {
            throw DrawingChallengeRandomizerError.insufficientUniqueLabels(
                category: category,
                requested: count,
                available: labels.count
            )
        }
        labels.shuffle(using: &generator)
        return Array(labels.prefix(count))
    }

    private func randomFoodChallenge<Generator: RandomNumberGenerator>(
        excluding previousLabel: String?,
        using generator: inout Generator
    ) throws -> DrawingChallengeSelection {
        var labels = catalog.labels(in: .food)
        guard !labels.isEmpty else {
            throw DrawingChallengeRandomizerError.missingCategory(.food)
        }
        if labels.count > 1, let previousLabel {
            let normalizedPrevious = previousLabel.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            labels.removeAll { $0 == normalizedPrevious }
        }
        labels.shuffle(using: &generator)
        guard let label = labels.first else {
            throw DrawingChallengeRandomizerError.missingCategory(.food)
        }
        let result = selection(category: .food, label: label, using: &generator)
        try validate([result])
        return result
    }

    private func selection<Generator: RandomNumberGenerator>(
        category: DrawingCategory,
        label: String,
        using generator: inout Generator
    ) -> DrawingChallengeSelection {
        DrawingChallengeSelection(
            id: deterministicUUID(using: &generator),
            category: category,
            label: label
        )
    }

    private func validate(_ selections: [DrawingChallengeSelection]) throws {
        var labels = Set<String>()
        for selection in selections {
            guard catalog.availableLabels.contains(selection.label) else {
                throw DrawingChallengeRandomizerError.labelMissingFromCatalog(selection.label)
            }
            guard catalog.contains(selection.label, in: selection.category) else {
                throw DrawingChallengeRandomizerError.labelMissingFromCatalog(selection.label)
            }
            guard labels.insert(selection.label).inserted else {
                throw DrawingChallengeRandomizerError.duplicateSelection(selection.label)
            }
        }
    }

    private func deterministicUUID<Generator: RandomNumberGenerator>(
        using generator: inout Generator
    ) -> UUID {
        let first = generator.next()
        let second = generator.next()
        var bytes = withUnsafeBytes(of: first.bigEndian, Array.init)
            + withUnsafeBytes(of: second.bigEndian, Array.init)
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

struct SeededDrawingChallengeGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0xA409_3822_299F_31D0 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
