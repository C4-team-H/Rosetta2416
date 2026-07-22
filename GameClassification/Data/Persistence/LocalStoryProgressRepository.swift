import Foundation
import SwiftData

@Model
final class StoryProgressRecord {
    var id: String
    @Attribute(.externalStorage) var latestData: Data
    @Attribute(.externalStorage) var checkpointData: Data
    var isContinueAvailable: Bool = false
    var updatedAt: Date

    init(
        id: String = "current",
        latestData: Data,
        checkpointData: Data,
        isContinueAvailable: Bool = false,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.latestData = latestData
        self.checkpointData = checkpointData
        self.isContinueAvailable = isContinueAvailable
        self.updatedAt = updatedAt
    }
}

@MainActor
final class LocalStoryProgressRepository: StoryProgressRepository {
    private let container: ModelContainer
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(container: ModelContainer) {
        self.container = container
    }

    convenience init(inMemory: Bool = false) throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        let container = try ModelContainer(for: StoryProgressRecord.self, configurations: configuration)
        self.init(container: container)
    }

    func save(_ progress: PersistedStoryProgress) async throws {
        let context = container.mainContext
        let latestData = try encoder.encode(progress.latest)
        let checkpointData = try encoder.encode(progress.checkpoint)
        let records = try context.fetch(FetchDescriptor<StoryProgressRecord>())

        if let record = records.first {
            record.latestData = latestData
            record.checkpointData = checkpointData
            record.isContinueAvailable = progress.isContinueAvailable
            record.updatedAt = .now
            for duplicate in records.dropFirst() { context.delete(duplicate) }
        } else {
            context.insert(StoryProgressRecord(
                latestData: latestData,
                checkpointData: checkpointData,
                isContinueAvailable: progress.isContinueAvailable
            ))
        }
        try context.save()
    }

    func load() async throws -> PersistedStoryProgress? {
        let records = try container.mainContext.fetch(FetchDescriptor<StoryProgressRecord>())
        guard let record = records.max(by: { $0.updatedAt < $1.updatedAt }) else { return nil }
        let latest = try decoder.decode(StorySaveSnapshot.self, from: record.latestData)
        let checkpoint = try decoder.decode(StorySaveSnapshot.self, from: record.checkpointData)
        guard latest.schemaVersion <= StorySaveSnapshot.currentSchemaVersion,
              checkpoint.schemaVersion <= StorySaveSnapshot.currentSchemaVersion else {
            throw StoryPersistenceError.unsupportedSchema
        }
        let progress = PersistedStoryProgress(
            latest: latest,
            checkpoint: checkpoint,
            isContinueAvailable: record.isContinueAvailable
        )
        let migrated = CheckpointSystem.migrate(progress)
        if latest.schemaVersion < StorySaveSnapshot.currentSchemaVersion
            || checkpoint.schemaVersion < StorySaveSnapshot.currentSchemaVersion {
            try await save(migrated)
        }
        return migrated
    }

    func clear() async throws {
        let context = container.mainContext
        for record in try context.fetch(FetchDescriptor<StoryProgressRecord>()) {
            context.delete(record)
        }
        try context.save()
    }
}

enum StoryPersistenceError: Error {
    case unsupportedSchema
}

@MainActor
final class InMemoryStoryProgressRepository: StoryProgressRepository {
    private var progress: PersistedStoryProgress?

    func save(_ progress: PersistedStoryProgress) async throws {
        self.progress = progress
    }

    func load() async throws -> PersistedStoryProgress? { progress.map(CheckpointSystem.migrate) }

    func clear() async throws { progress = nil }
}
