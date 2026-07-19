import CoreGraphics
import Foundation
import SpriteKit
import Testing
@testable import GameClassification

@Suite("Persistence and derived presentation")
@MainActor
struct PersistenceAndMapTests {
    @Test("SwiftData round trips schema-v2 state and checkpoint snapshots")
    func swiftDataRoundTrip() async throws {
        let repository = try LocalStoryProgressRepository(inMemory: true)
        var story = StoryState.initial
        story.deliveredDialogueIDs.insert("intro-sleeping")
        story.selectedChallengeLabels["lab-memory-repair"] = "cat"
        story.albumBook.hasOpenedBook = true
        story.albumBook.isMarkerVisible = true
        story.albumBook.isMarkerPermanent = true
        let latest = snapshot(story: story, energy: 72, spawn: CGPoint(x: 10, y: 20))
        let checkpoint = snapshot(story: .initial, energy: 55, spawn: CGPoint(x: 30, y: 40))

        try await repository.save(PersistedStoryProgress(latest: latest, checkpoint: checkpoint))
        let loaded = try await repository.load()

        #expect(loaded?.latest == latest)
        #expect(loaded?.checkpoint == checkpoint)
        #expect(loaded?.latest.schemaVersion == 2)
        #expect(loaded?.latest.sharedStory.selectedChallengeLabels["lab-memory-repair"] == "cat")
        #expect(loaded?.latest.sharedStory.albumBook.isMarkerPermanent == true)

        try await repository.clear()
        #expect(try await repository.load() == nil)
    }

    @Test("Schema-v1 easels migrate to categorized physical stations and schema v2")
    func schemaV1Migration() throws {
        let legacyJSON = """
        {
          "currentChapter": "enginePhaseOne",
          "intelligence": 40,
          "engineProgress": 0,
          "completedObjectiveIDs": ["reach-laboratory", "lab-easel"],
          "easelSelectedLabels": {"lab-easel": ["hand", "cat", "tree"]},
          "easelCompletedLabels": {"lab-easel": ["hand", "cat", "tree"]},
          "hasOpenedAlbum": true,
          "deliveredDialogueIDs": ["intro-1"],
          "latestCheckpoint": "laboratory"
        }
        """
        let migratedState = try JSONDecoder().decode(StoryState.self, from: Data(legacyJSON.utf8))
        let story = StoryProgressionSystem(state: migratedState)

        #expect(story.state.currentChapter == .engineInitial)
        #expect(story.state.selectedChallengeLabels["lab-memory-repair"] == "cat")
        #expect(story.state.selectedChallengeLabels["lab-scanner-repair"] == "tree")
        #expect(story.state.selectedChallengeLabels["lab-terminal-repair"] == "hand")
        #expect(story.state.completedChallengeIDs.isSuperset(of: StoryConfiguration.laboratoryChallenges.map(\.id)))
        #expect(story.state.albumBook.hasOpenedBook)
        #expect(story.state.albumBook.isMarkerPermanent)
        #expect(story.state.deliveredDialogueIDs.contains("intro-1"))

        let snapshot = snapshot(story: story.state, energy: 75, spawn: CGPoint(x: 12, y: 34))
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any])
        object["schemaVersion"] = 1
        let legacySnapshot = try JSONDecoder().decode(
            StorySaveSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        let migrated = CheckpointSystem.migrate(PersistedStoryProgress(latest: legacySnapshot, checkpoint: legacySnapshot))
        #expect(migrated.latest.schemaVersion == 2)
        #expect(migrated.checkpoint.schemaVersion == 2)
        #expect(migrated.latest.sharedStory.selectedChallengeLabels == story.state.selectedChallengeLabels)
    }

    @Test("Map configuration contains every one of the nine canonical checkpoints")
    func checkpointCatalog() {
        let configured = Set(MapGeometryConfiguration.drawingSpaceDefault.checkpoints.compactMap(\.checkpointID))
        #expect(CheckpointID.allCases.count == 9)
        #expect(configured == Set(CheckpointID.allCases))
    }

    @Test("Opening the Album makes its marker permanent and idempotent")
    func albumOpen() {
        let story = StoryProgressionSystem()
        _ = story.handle(.drawingFailed)
        #expect(story.markAlbumOpened().contains(.mapNeedsRefresh))
        #expect(story.state.albumBook.hasOpenedBook)
        #expect(story.state.albumBook.isMarkerPermanent)
        #expect(story.markAlbumOpened().isEmpty)
    }

    @Test("Visibility has active station, permanent Kitchen, repaired Storage prop, and no stale markers")
    func centralizedVisibility() {
        var state = StoryState.initial
        state.currentChapter = .storage
        state.completedChallengeIDs = Set(
            StoryConfiguration.laboratoryChallenges.map(\.id)
                + StoryConfiguration.engineInitialChallenges.map(\.id)
                + ["storage-tool-terminal"]
        )
        let story = StoryProgressionSystem(state: state)
        let visibility = StationVisibilitySystem(storySystem: story, isDebugEnabled: false)

        #expect(visibility.visibility(interactionID: "storage-tool-terminal") == .worldOnly)
        #expect(visibility.visibility(interactionID: "storage-robotic-arm") == .worldAndMap)
        #expect(visibility.visibility(interactionID: "storage-calibration-unit") == .hidden)
        #expect(visibility.visibility(interactionID: "engine-pressure-feed") == .hidden)
        #expect(visibility.visibility(interactionID: StationVisibilitySystem.kitchenInteractionID) == .worldAndMap)

        let markers = TacticalMapMarkerFactory.make(
            story: story,
            configuration: .drawingSpaceDefault,
            visibilitySystem: visibility
        ).filter(\.isVisible)
        #expect(markers.contains { $0.id.contains("storage-robotic-arm") })
        #expect(!markers.contains { $0.id.contains("storage-tool-terminal") })
        #expect(markers.contains { $0.id == "kitchen" })
    }

    @Test("Kitchen is world-and-map visible for every story chapter")
    func kitchenAlwaysVisible() {
        for chapter in StoryChapter.allCases {
            var state = StoryState.initial
            state.currentChapter = chapter
            let story = StoryProgressionSystem(state: state)
            let visibility = StationVisibilitySystem(storySystem: story, isDebugEnabled: false)
            #expect(visibility.visibility(interactionID: StationVisibilitySystem.kitchenInteractionID) == .worldAndMap)
        }
    }

    @Test("Emergency map has travel destination; Engine 10 keeps full reveal through disruption")
    func mapReveal() {
        let initial = StoryProgressionSystem()
        let initialVisibility = StationVisibilitySystem(storySystem: initial, isDebugEnabled: false)
        let initialMarkers = TacticalMapMarkerFactory.make(
            story: initial,
            configuration: .drawingSpaceDefault,
            visibilitySystem: initialVisibility
        ).filter(\.isVisible)
        #expect(initialMarkers.contains { $0.id == "room-laboratory" })
        #expect(initialMarkers.contains { $0.id == "kitchen" })
        #expect(!initialMarkers.contains { $0.kind == .door })

        let session = makeSession()
        session.beginGameplay()
        _ = session.handle(.roomEntered(.laboratory))
        complete(.laboratory, in: session)
        validate("engine-ignition-coil", in: session)
        let viewModel = TacticalMapViewModel(sessionState: session)
        #expect(viewModel.isFullMapRevealed)

        for definition in StoryConfiguration.engineInitialChallenges.dropFirst().prefix(3) {
            validate(definition.id, in: session)
        }
        #expect(session.sharedStory.powerState == .disrupted)
        #expect(viewModel.isFullMapRevealed)
    }

    @Test("Album physical book and marker use the same console-derived coordinate")
    func albumCoordinateAndMarker() {
        let configuration = MapGeometryConfiguration.drawingSpaceDefault
        let console = configuration.objects.first { $0.id == "object-sleeping-main-console" }
        #expect(console != nil)
        #expect(configuration.albumBookPosition == CGPoint(
            x: (console?.position.x ?? .zero) - 10,
            y: console?.position.y ?? .zero
        ))

        let story = StoryProgressionSystem()
        _ = story.handle(.drawingFailed)
        let visibility = StationVisibilitySystem(storySystem: story, isDebugEnabled: false)
        let marker = TacticalMapMarkerFactory.make(
            story: story,
            configuration: configuration,
            visibilitySystem: visibility
        ).first { $0.id == "album-book" }
        #expect(marker?.worldPosition == configuration.albumBookPosition)
    }

    @Test("Album sprite uses one shader-backed sprite and follows the interaction radius")
    func albumProximityHighlight() {
        let session = makeSession()
        session.beginGameplay()
        let mapViewModel = TacticalMapViewModel(sessionState: session)
        let scene = GameScene(
            size: CGSize(width: 1_024, height: 768),
            sessionState: session,
            tacticalMapViewModel: mapViewModel
        )
        scene.createPlayer()
        scene.createAlbumBook()

        guard let book = scene.albumBookNode else {
            Issue.record("Album Book node was not created")
            return
        }
        #expect(book.position == MapGeometryConfiguration.drawingSpaceDefault.albumBookPosition)
        #expect(book.artworkSize == CGSize(width: 209, height: 224))
        #expect(book.artworkSprite.size.width == (209 + 8) * AlbumBookNode.artworkScale)
        #expect(book.artworkSprite.size.height == (224 + 8) * AlbumBookNode.artworkScale)
        #expect(book.artworkSprite.xScale == 1)
        #expect(book.artworkSprite.yScale == 1)
        #expect(book.children.count == 1)
        #expect(book.children.first === book.artworkSprite)
        #expect(book.artworkSprite.shader != nil)
        #expect(!book.isProximityHighlighted)

        scene.player.position = book.position
        scene.checkProximityToAlbumBook()
        #expect(book.isProximityHighlighted)
        #expect(book.action(forKey: "album-book-highlight-transition") != nil)
        #expect(scene.albumBookButton != nil)

        scene.player.position = CGPoint(
            x: book.position.x + AlbumBookNode.interactionRadius + 1,
            y: book.position.y
        )
        scene.checkProximityToAlbumBook()
        #expect(!book.isProximityHighlighted)
        #expect(scene.albumBookButton == nil)

        book.removeFromParent()
        book.setProximityHighlighted(true, animated: false)
        let renderScene = SKScene(size: book.artworkSprite.size)
        book.position = CGPoint(x: renderScene.size.width / 2, y: renderScene.size.height / 2)
        renderScene.addChild(book)
        let renderView = SKView(frame: CGRect(origin: .zero, size: renderScene.size))
        renderView.allowsTransparency = true
        renderView.presentScene(renderScene)
        #expect(renderView.texture(from: book) != nil)
    }

    @Test("Kitchen table replaces the Kitchen Food Station visual and proximity")
    func kitchenTableFoodStationProximityHighlight() {
        let configuration = MapGeometryConfiguration.drawingSpaceDefault
        let sideCounter = configuration.objects.first { $0.id == "object-kitchen-side-counter" }
        #expect(sideCounter != nil)
        #expect(configuration.kitchenTablePosition == CGPoint(
            x: sideCounter?.position.x ?? .zero,
            y: (sideCounter?.position.y ?? .zero) + 6
        ))

        let session = makeSession()
        session.beginGameplay()
        let mapViewModel = TacticalMapViewModel(sessionState: session)
        let scene = GameScene(
            size: CGSize(width: 1_024, height: 768),
            sessionState: session,
            tacticalMapViewModel: mapViewModel
        )
        scene.createShipMap()
        scene.createPlayer()
        scene.createFoodObject()

        guard let table = scene.foodObject else {
            Issue.record("Kitchen Table node was not created")
            return
        }
        let padding = ceil(KitchenTableNode.outlineWidth) + 2
        #expect(table.position == configuration.kitchenTablePosition)
        #expect(table.artworkSize == CGSize(width: 211, height: 253))
        #expect(table.artworkSprite.size == CGSize(
            width: (table.artworkSize.width + padding * 2) * KitchenTableNode.artworkScale,
            height: (table.artworkSize.height + padding * 2) * KitchenTableNode.artworkScale
        ))
        #expect(table.artworkSprite.xScale == 1)
        #expect(table.artworkSprite.yScale == 1)
        #expect(table.children.count == 1)
        #expect(table.children.first === table.artworkSprite)
        #expect(table.artworkSprite.shader != nil)
        #expect(!table.isProximityHighlighted)

        scene.player.position = table.position
        scene.checkProximityToFoodObject()
        #expect(table.isProximityHighlighted)
        #expect(table.action(forKey: "kitchen-table-highlight-transition") != nil)
        #expect(scene.foodActionButton != nil)

        scene.player.position = CGPoint(
            x: table.position.x + KitchenTableNode.interactionRadius + 1,
            y: table.position.y
        )
        scene.checkProximityToFoodObject()
        #expect(!table.isProximityHighlighted)
        #expect(scene.foodActionButton == nil)
    }

    @Test("Delivered dialogue does not replay after restoration")
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
        var restored = StoryState.initial
        restored.deliveredDialogueIDs.insert("saved-line")
        #expect(manager.nextLine(for: .chapterEntered(.sleepingRoom), story: restored) == nil)
    }

    private func snapshot(story: StoryState, energy: Double, spawn: CGPoint) -> StorySaveSnapshot {
        StorySaveSnapshot(
            sharedStory: story,
            localSurvival: PlayerSurvivalState(playerID: "local", energy: energy),
            safeSpawn: spawn,
            stats: GameSessionStats()
        )
    }

    private func complete(_ chapter: StoryChapter, in session: GameSessionState) {
        for definition in StoryConfiguration.challenges(for: chapter) { validate(definition.id, in: session) }
    }

    private func validate(_ id: String, in session: GameSessionState) {
        guard let prompt = session.storySystem.currentPrompt(for: id) else { return }
        _ = session.handle(.drawingValidated(
            objectiveID: id,
            result: RecognitionResult(label: prompt.expectedLabel, confidence: 1, alternatives: [])
        ))
    }

    private func makeSession() -> GameSessionState {
        GameSessionState(localPlayer: PlayerState(
            id: "local", name: "Player", worldPosition: GameMapLayout.playerSpawnPosition, isConnected: true
        ))
    }
}
