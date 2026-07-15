import Foundation

struct PersistedStoryProgress: Codable, Equatable, Sendable {
    var latest: StorySaveSnapshot
    var checkpoint: StorySaveSnapshot
}

@MainActor
protocol StoryProgressRepository: AnyObject {
    func save(_ progress: PersistedStoryProgress) async throws
    func load() async throws -> PersistedStoryProgress?
    func clear() async throws
}

