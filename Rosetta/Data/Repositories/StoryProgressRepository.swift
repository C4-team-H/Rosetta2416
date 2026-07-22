import Foundation

struct PersistedStoryProgress: Codable, Equatable, Sendable {
    var latest: StorySaveSnapshot
    var checkpoint: StorySaveSnapshot
    var isContinueAvailable: Bool

    init(
        latest: StorySaveSnapshot,
        checkpoint: StorySaveSnapshot,
        isContinueAvailable: Bool = false
    ) {
        self.latest = latest
        self.checkpoint = checkpoint
        self.isContinueAvailable = isContinueAvailable
    }

    private enum CodingKeys: String, CodingKey {
        case latest
        case checkpoint
        case isContinueAvailable
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        latest = try container.decode(StorySaveSnapshot.self, forKey: .latest)
        checkpoint = try container.decode(StorySaveSnapshot.self, forKey: .checkpoint)
        isContinueAvailable = try container.decodeIfPresent(Bool.self, forKey: .isContinueAvailable) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latest, forKey: .latest)
        try container.encode(checkpoint, forKey: .checkpoint)
        try container.encode(isContinueAvailable, forKey: .isContinueAvailable)
    }
}

@MainActor
protocol StoryProgressRepository: AnyObject {
    func save(_ progress: PersistedStoryProgress) async throws
    func load() async throws -> PersistedStoryProgress?
    func clear() async throws
}
