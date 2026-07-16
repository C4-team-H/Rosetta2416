import CoreGraphics
import Testing
@testable import GameClassification

@Suite("Persistence and derived presentation")
@MainActor
struct PersistenceAndMapTests {
    @Test("SwiftData in-memory repository round trips latest and checkpoint snapshots")
    func swiftDataRoundTrip() async throws {
        let repository = try LocalStoryProgressRepository(inMemory: true)
        var story = SharedStoryState.initial
        story.deliveredDialogueIDs.insert("intro-sleeping")
        let latest = snapshot(story: story, energy: 72, spawn: CGPoint(x: 10, y: 20))
        let checkpoint = snapshot(story: .initial, energy: 55, spawn: CGPoint(x: 30, y: 40))

        try await repository.save(PersistedStoryProgress(latest: latest, checkpoint: checkpoint))
        let loaded = try await repository.load()

        #expect(loaded?.latest == latest)
        #expect(loaded?.checkpoint == checkpoint)
        #expect(loaded?.latest.sharedStory.deliveredDialogueIDs.contains("intro-sleeping") == true)

        try await repository.clear()
        #expect(try await repository.load() == nil)
    }

    @Test("Map markers derive locked and unlocked room status from story state")
    func mapMarkers() {
        let initial = StoryProgressionSystem()
        let initialMarkers = TacticalMapMarkerFactory.make(story: initial)
        #expect(status(of: "room-engine", in: initialMarkers) == .locked)
        #expect(status(of: "room-cockpit", in: initialMarkers) == .locked)

        var restored = SharedStoryState.initial
        restored.currentChapter = .cockpit
        restored.intelligence = 100
        restored.engineProgress = 100
        restored.hasAdvancedTools = true
        restored.powerState = .fullyRestored
        restored.completedObjectiveIDs = Set(
            ["reach-laboratory"] + StoryContent.labIDs + StoryContent.engineEaselOneIDs
                + StoryContent.storageIDs + StoryContent.engineFinalIDs
        )
        let completeEngine = StoryProgressionSystem(state: restored)
        let completeMarkers = TacticalMapMarkerFactory.make(story: completeEngine)

        #expect(status(of: "room-engine", in: completeMarkers) == .unlocked)
        #expect(status(of: "room-storage", in: completeMarkers) == .unlocked)
        #expect(status(of: "room-cockpit", in: completeMarkers) == .unlocked)
    }

    @Test("Delivered dialogue does not replay after state restoration")
    func dialogueDoesNotReplay() {
        let manager = AIDialogueManager(lines: [
            AIDialogueLine(
                id: "saved-line",
                chapter: .sleepingRoom,
                trigger: .chapterEntered(.sleepingRoom),
                text: "Saved",
                priority: 1
            )
        ])
        var restored = SharedStoryState.initial
        restored.deliveredDialogueIDs.insert("saved-line")

        #expect(manager.nextLine(for: .chapterEntered(.sleepingRoom), story: restored) == nil)
    }

    private func snapshot(story: SharedStoryState, energy: Double, spawn: CGPoint) -> StorySaveSnapshot {
        StorySaveSnapshot(
            sharedStory: story,
            localSurvival: PlayerSurvivalState(playerID: "local", energy: energy),
            safeSpawn: spawn,
            stats: GameSessionStats()
        )
    }

    private func status(of id: String, in markers: [MapMarker]) -> MapMarkerStatus? {
        markers.first(where: { $0.id == id })?.status
    }
}
