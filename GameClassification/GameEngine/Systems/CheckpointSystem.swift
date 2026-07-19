import Foundation

struct CheckpointSystem: Sendable {
    private(set) var latestCheckpoint: StorySaveSnapshot

    init(initialSnapshot: StorySaveSnapshot) {
        latestCheckpoint = initialSnapshot
    }

    mutating func record(_ snapshot: StorySaveSnapshot) {
        latestCheckpoint = snapshot
    }

    mutating func restoreRecord(_ snapshot: StorySaveSnapshot) {
        latestCheckpoint = snapshot
    }

    func restorationSpawn(fallback: CGPoint) -> CGPoint {
        latestCheckpoint.safeSpawn.isFinite ? latestCheckpoint.safeSpawn : fallback
    }

    static func migrate(_ progress: PersistedStoryProgress) -> PersistedStoryProgress {
        guard progress.latest.schemaVersion < StorySaveSnapshot.currentSchemaVersion
                || progress.checkpoint.schemaVersion < StorySaveSnapshot.currentSchemaVersion else {
            return progress
        }
        return PersistedStoryProgress(
            latest: migratedSnapshot(progress.latest),
            checkpoint: migratedSnapshot(progress.checkpoint)
        )
    }

    private static func migratedSnapshot(_ snapshot: StorySaveSnapshot) -> StorySaveSnapshot {
        StorySaveSnapshot(
            sharedStory: snapshot.sharedStory,
            localSurvival: snapshot.localSurvival,
            safeSpawn: snapshot.safeSpawn,
            stats: snapshot.stats,
            savedAt: snapshot.savedAt
        )
    }
}
