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
        _ = story.handle(.drawingFailed())
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
    }

    @Test("MainEngineControlNode position derives from object-engine-core anchor")
    func mainEngineCorePosition() {
        let config = MapGeometryConfiguration.drawingSpaceDefault
        let anchor = config.objects.first(where: { $0.id == "object-engine-core" })
        #expect(anchor != nil)
        #expect(config.mainEngineCorePosition == anchor?.position.cgPoint)
    }

    @Test("MainEngineControlNode structure has artwork sprite and shader")
    func mainEngineControlNodeStructure() {
        let node = MainEngineControlNode()
        #expect(node.children.count == 1)
        #expect(node.artworkSprite.name == "main-engine-control-artwork")
        #expect(node.artworkSprite.shader != nil)
        #expect(node.artworkSprite.xScale == 1)
        #expect(node.artworkSprite.yScale == 1)
        #expect(MainEngineControlNode.interactionRadius == GameMapLayout.scaled(76))
        #expect(MainEngineControlNode.outlineWidth == GameMapLayout.scaled(2))
    }

    @Test("MainEngineControl proximity activates highlight and REPAIR button")
    func mainEngineControlProximity() throws {
        let session = makeSession()
        session.beginGameplay()
        let scene = makeScene(session: session)
        complete(.laboratory, in: session)
        validate("engine-ignition-coil", in: session)
        validate("engine-cooling-valve", in: session)
        validate("engine-cooling-restart", in: session)
        validate("engine-reactor-link", in: session)
        var s1 = session.sharedStory
        s1.currentChapter = .engineFinal
        session.storySystem.restore(s1)

        let mainEngine = try #require(scene.mainEngineControlNode)
        scene.player.position = mainEngine.position
        scene.checkProximityToInteractiveObject()

        #expect(mainEngine.isProximityHighlighted)
        #expect(scene.activeStationID == "engine-calibration-port")
        #expect(scene.actionButton != nil)
    }

    @Test("MainEngineControl leaving radius clears highlight and UI")
    func mainEngineControlLeaveRadius() throws {
        let session = makeSession()
        session.beginGameplay()
        let scene = makeScene(session: session)
        complete(.laboratory, in: session)
        validate("engine-ignition-coil", in: session)
        validate("engine-cooling-valve", in: session)
        validate("engine-cooling-restart", in: session)
        validate("engine-reactor-link", in: session)
        var s2 = session.sharedStory
        s2.currentChapter = .engineFinal
        session.storySystem.restore(s2)

        let mainEngine = try #require(scene.mainEngineControlNode)
        scene.player.position = mainEngine.position
        scene.checkProximityToInteractiveObject()
        #expect(mainEngine.isProximityHighlighted)

        scene.player.position = CGPoint(x: mainEngine.position.x + 200, y: mainEngine.position.y)
        scene.checkProximityToInteractiveObject()

        #expect(!mainEngine.isProximityHighlighted)
        #expect(scene.activeStationID == nil)
        #expect(scene.actionButton == nil)
    }

    @Test("Inactive MainEngineControl mission hides node and clears interaction")
    func mainEngineControlInactiveMission() throws {
        let session = makeSession()
        session.beginGameplay()
        let scene = makeScene(session: session)
        complete(.laboratory, in: session)

        let mainEngine = try #require(scene.mainEngineControlNode)
        scene.refreshStoryVisuals()

        #expect(mainEngine.isHidden)
        #expect(!mainEngine.isProximityHighlighted)
    }

    @Test("Active MainEngineControl mission shows node and enables interaction")
    func mainEngineControlActiveMission() throws {
        let session = makeSession()
        session.beginGameplay()
        let scene = makeScene(session: session)
        complete(.laboratory, in: session)
        validate("engine-ignition-coil", in: session)
        validate("engine-cooling-valve", in: session)
        validate("engine-cooling-restart", in: session)
        validate("engine-reactor-link", in: session)
        var s3 = session.sharedStory
        s3.currentChapter = .engineFinal
        session.storySystem.restore(s3)

        let mainEngine = try #require(scene.mainEngineControlNode)
        scene.refreshStoryVisuals()

        #expect(!mainEngine.isHidden)
        scene.player.position = mainEngine.position
        scene.checkProximityToInteractiveObject()
        #expect(mainEngine.isProximityHighlighted)
        #expect(scene.activeStationID == "engine-calibration-port")
    }

    @Test("Seven engine-core stations do not create legacy rectangle nodes")
    func mainEngineCoreStationsExcluded() {
        let session = makeSession()
        session.beginGameplay()
        let scene = makeScene(session: session)

        let coreStationIDs = GameScene.mainEngineCoreInteractionIDs
        for stationID in coreStationIDs {
            #expect(scene.stationNodes[stationID] == nil)
        }
    }

    @Test("TacticalMap markers for engine-core missions use mainEngineCorePosition")
    func mainEngineCoreMarkerPosition() {
        let session = makeSession()
        session.beginGameplay()
        complete(.laboratory, in: session)
        validate("engine-ignition-coil", in: session)
        validate("engine-cooling-valve", in: session)
        validate("engine-cooling-restart", in: session)
        validate("engine-reactor-link", in: session)
        var s4 = session.sharedStory
        s4.currentChapter = .engineFinal
        session.storySystem.restore(s4)

        let config = MapGeometryConfiguration.drawingSpaceDefault
        let markers = TacticalMapMarkerFactory.make(
            story: session.storySystem,
            configuration: config,
            visibilitySystem: StationVisibilitySystem(storySystem: session.storySystem, isDebugEnabled: false)
        )

        let corePosition = config.mainEngineCorePosition
        let coreMarkers = markers.filter {
            GameScene.mainEngineCoreInteractionIDs.contains($0.id.replacingOccurrences(of: "station-", with: ""))
        }

        for marker in coreMarkers {
            #expect(marker.worldPosition == corePosition)
        }
    }

    @Test("MainEngineControl accumulated Z is below candle overlay")
    func mainEngineControlZOrdering() throws {
        let session = makeSession()
        session.beginGameplay()
        let scene = makeScene(session: session)

        let shipMap = try #require(scene.shipMapNode)
        let mainEngine = try #require(scene.mainEngineControlNode)
        let candleLight = try #require(scene.candleLight)

        let objectWorldZ = shipMap.zPosition + shipMap.furnitureLayer.zPosition + mainEngine.zPosition
        let candleWorldZ = scene.cameraNode.zPosition + candleLight.zPosition
        let hudWorldZ = scene.cameraNode.zPosition + (scene.joystickBase?.zPosition ?? 0)

        #expect(objectWorldZ < candleWorldZ)
        #expect(candleWorldZ < hudWorldZ)
    }

    @Test("Album physical book and marker use the same console-derived coordinate")
    func albumCoordinateAndMarker() {
        let configuration = MapGeometryConfiguration.drawingSpaceDefault
        let console = configuration.objects.first { $0.id == "object-sleeping-main-console" }
        #expect(console != nil)
        #expect(configuration.albumBookPosition == CGPoint(
            x: (console?.position.x ?? .zero) - 8,
            y: console?.position.y ?? .zero
        ))

        let story = StoryProgressionSystem()
        _ = story.handle(.drawingFailed())
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
            y: (sideCounter?.position.y ?? .zero) + 2
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

    @Test("Lab table position is derived from object-lab-main-table with +6 Y offset")
    func labTablePositionDerivation() {
        let configuration = MapGeometryConfiguration.drawingSpaceDefault
        let anchor = configuration.objects.first { $0.id == "object-lab-main-table" }
        #expect(anchor != nil)
        #expect(configuration.labTablePosition == CGPoint(
            x: (anchor?.position.x ?? .zero) - 4,
            y: (anchor?.position.y ?? .zero) + 46
        ))
    }

    @Test("Lab table replaces station-lab-scanner-repair visual and shows proximity highlight")
    func labTableProximityHighlight() {
        let configuration = MapGeometryConfiguration.drawingSpaceDefault
        let anchor = configuration.objects.first { $0.id == "object-lab-main-table" }
        #expect(anchor != nil)

        let session = makeSession()
        session.beginGameplay()
        _ = session.handle(.roomEntered(.laboratory))
        validate("lab-memory-repair", in: session)
        let mapViewModel = TacticalMapViewModel(sessionState: session)
        let scene = GameScene(
            size: CGSize(width: 1_024, height: 768),
            sessionState: session,
            tacticalMapViewModel: mapViewModel
        )
        scene.createShipMap()
        scene.createPlayer()
        scene.createInteractiveStations()
        scene.createLabTable()

        guard let labTable = scene.labTableNode else {
            Issue.record("Lab Table node was not created")
            return
        }
        #expect(scene.stationNodes[GameScene.labScannerRepairInteractionID] == nil)
        let padding = ceil(LabTableNode.outlineWidth) + 2
        #expect(labTable.position == configuration.labTablePosition)
        #expect(labTable.artworkSize == CGSize(width: 294, height: 186))
        #expect(labTable.artworkSprite.size == CGSize(
            width: (labTable.artworkSize.width + padding * 2) * LabTableNode.artworkScale,
            height: (labTable.artworkSize.height + padding * 2) * LabTableNode.artworkScale
        ))
        #expect(labTable.artworkSprite.xScale == 1)
        #expect(labTable.artworkSprite.yScale == 1)
        #expect(labTable.children.count == 1)
        #expect(labTable.children.first === labTable.artworkSprite)
        #expect(labTable.artworkSprite.shader != nil)
        #expect(!labTable.isProximityHighlighted)

        scene.player.position = labTable.position
        scene.checkProximityToInteractiveObject()
        #expect(labTable.isProximityHighlighted)
        #expect(labTable.action(forKey: "lab-table-highlight-transition") != nil)
        #expect(scene.activeStationID == GameScene.labScannerRepairInteractionID)
        #expect(scene.actionButton != nil)

        scene.player.position = CGPoint(
            x: labTable.position.x + LabTableNode.interactionRadius + 1,
            y: labTable.position.y
        )
        scene.checkProximityToInteractiveObject()
        #expect(!labTable.isProximityHighlighted)
        #expect(scene.activeStationID == nil)
        #expect(scene.actionButton == nil)

        labTable.isHidden = true
        labTable.setProximityHighlighted(true, animated: false)
        scene.checkProximityToInteractiveObject()
        #expect(!labTable.isProximityHighlighted)
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

    private func makeScene(session: GameSessionState) -> GameScene {
        GameScene(
            size: CGSize(width: 1_024, height: 768),
            sessionState: session,
            tacticalMapViewModel: TacticalMapViewModel(sessionState: session)
        )
    }

    private func makeSession() -> GameSessionState {
        GameSessionState(localPlayer: PlayerState(
            id: "local", name: "Player", worldPosition: GameMapLayout.playerSpawnPosition, isConnected: true
        ))
    }

    private func makeScene(session: GameSessionState) -> GameScene {
        let scene = GameScene(
            size: CGSize(width: 1_024, height: 768),
            sessionState: session,
            tacticalMapViewModel: TacticalMapViewModel(sessionState: session)
        )
        scene.addChild(scene.cameraNode)
        scene.camera = scene.cameraNode
        scene.cameraNode.setScale(GameScene.gameplayCameraScale)
        scene.createShipMap()
        scene.createPlayer()
        scene.createJoystick()
        scene.createInteractiveStations()
        scene.createFoodObject()
        scene.createAlbumBook()
        scene.createLabTable()
        scene.createLabMonitor2()
        scene.createLabMonitor1()
        scene.createEngineMonitor()
        scene.createEnginePipeControl()
        scene.createMainEngineControl()
        scene.createStorageMonitor()
        scene.createStorageMachinery()
        scene.createStorageCabinet()
        scene.createCockpitPortMonitor()
        scene.createCockpitMainConsole()
        scene.createRocketPowerOffSmoke()
        scene.enableCandleLight()
        scene.refreshStoryVisuals()
        return scene
    }

    private func forceChapter(_ chapter: StoryChapter, in session: GameSessionState) {
        var story = session.sharedStory
        story.currentChapter = chapter
        session.storySystem.restore(story)
    }
}

// MARK: - Lab Monitor 2

@Suite("Lab Monitor 2")
@MainActor
struct LabMonitor2Tests {
    @Test("Lab Monitor 2 position derived from object-lab-monitor-2 with offset y+6")
    func labMonitor2Coordinate() {
        let configuration = MapGeometryConfiguration.drawingSpaceDefault
        let anchor = configuration.objects.first { $0.id == "object-lab-monitor-2" }
        #expect(anchor != nil)
        #expect(configuration.labMonitor2Position == CGPoint(
            x: anchor?.position.x ?? .zero,
            y: (anchor?.position.y ?? .zero) + 6
        ))
    }

    @Test("Lab Monitor 2 sprite uses one shader-backed sprite and follows the interaction radius")
    func labMonitor2ProximityHighlight() {
        let session = makeSession()
        session.beginGameplay()
        _ = session.handle(.roomEntered(.laboratory))
        for id in ["lab-memory-repair", "lab-scanner-repair"] { validate(id, in: session) }
        let mapViewModel = TacticalMapViewModel(sessionState: session)
        let scene = GameScene(
            size: CGSize(width: 1_024, height: 768),
            sessionState: session,
            tacticalMapViewModel: mapViewModel
        )
        scene.createPlayer()
        scene.createLabMonitor2()

        guard let monitor = scene.labMonitor2Node else {
            Issue.record("Lab Monitor 2 node was not created")
            return
        }
        #expect(monitor.position == MapGeometryConfiguration.drawingSpaceDefault.labMonitor2Position)
        #expect(monitor.artworkSize == CGSize(width: 318, height: 186))
        #expect(monitor.artworkSprite.xScale == 1)
        #expect(monitor.artworkSprite.yScale == 1)
        #expect(monitor.children.count == 1)
        #expect(monitor.children.first === monitor.artworkSprite)
        #expect(monitor.artworkSprite.shader != nil)
        #expect(!monitor.isProximityHighlighted)

        scene.player.position = monitor.position
        scene.checkProximityToLabMonitor2()
        #expect(monitor.isProximityHighlighted)
        #expect(monitor.action(forKey: "lab-monitor-2-highlight-transition") != nil)

        scene.player.position = CGPoint(
            x: monitor.position.x + LabMonitor2Node.interactionRadius + 1,
            y: monitor.position.y
        )
        scene.checkProximityToLabMonitor2()
        #expect(!monitor.isProximityHighlighted)

        monitor.removeFromParent()
        monitor.setProximityHighlighted(true, animated: false)
        let renderScene = SKScene(size: monitor.artworkSprite.size)
        monitor.position = CGPoint(x: renderScene.size.width / 2, y: renderScene.size.height / 2)
        renderScene.addChild(monitor)
        let renderView = SKView(frame: CGRect(origin: .zero, size: renderScene.size))
        renderView.allowsTransparency = true
        renderView.presentScene(renderScene)
        #expect(renderView.texture(from: monitor) != nil)
    }

    @Test("Lab monitor 2 has no highlight when objective is not active")
    func labMonitor2NoHighlightWithoutObjective() {
        let session = makeSession()
        session.beginGameplay()
        let mapViewModel = TacticalMapViewModel(sessionState: session)
        let scene = GameScene(
            size: CGSize(width: 1_024, height: 768),
            sessionState: session,
            tacticalMapViewModel: mapViewModel
        )
        scene.createPlayer()
        scene.createLabMonitor2()
        guard let monitor = scene.labMonitor2Node else {
            Issue.record("Lab Monitor 2 node was not created")
            return
        }
        scene.player.position = monitor.position
        scene.checkProximityToLabMonitor2()
        #expect(!monitor.isProximityHighlighted)
    }

    @Test("Hidden lab monitor 2 clears highlight")
    func labMonitor2HiddenClearsHighlight() {
        let session = makeSession()
        session.beginGameplay()
        _ = session.handle(.roomEntered(.laboratory))
        for id in ["lab-memory-repair", "lab-scanner-repair"] { validate(id, in: session) }
        let mapViewModel = TacticalMapViewModel(sessionState: session)
        let scene = GameScene(
            size: CGSize(width: 1_024, height: 768),
            sessionState: session,
            tacticalMapViewModel: mapViewModel
        )
        scene.createPlayer()
        scene.createLabMonitor2()
        guard let monitor = scene.labMonitor2Node else {
            Issue.record("Lab Monitor 2 node was not created")
            return
        }
        monitor.isHidden = true
        scene.checkProximityToLabMonitor2()
        #expect(!monitor.isProximityHighlighted)
    }

    @Test("station-lab-terminal-repair is not created as a visual station node")
    func stationLabTerminalRepairNotCreated() {
        let session = makeSession()
        session.beginGameplay()
        let mapViewModel = TacticalMapViewModel(sessionState: session)
        let scene = GameScene(
            size: CGSize(width: 1_024, height: 768),
            sessionState: session,
            tacticalMapViewModel: mapViewModel
        )
        scene.createShipMap()
        scene.createInteractiveStations()
        #expect(scene.stationNodes["lab-terminal-repair"] == nil)
    }

    private func makeSession() -> GameSessionState {
        GameSessionState(localPlayer: PlayerState(
            id: "local", name: "Player", worldPosition: GameMapLayout.playerSpawnPosition, isConnected: true
        ))
    }

    private func validate(_ id: String, in session: GameSessionState) {
        guard let prompt = session.storySystem.currentPrompt(for: id) else { return }
        _ = session.handle(.drawingValidated(
            objectiveID: id,
            result: RecognitionResult(label: prompt.expectedLabel, confidence: 1, alternatives: [])
        ))
    }
}

@Suite("Rocket power-off smoke")
@MainActor
struct RocketPowerOffSmokeTests {
    @Test("Rocket power-off smoke uses the requested world coordinate")
    func rocketPowerOffSmokeCoordinate() {
        let position = MapGeometryConfiguration.drawingSpaceDefault.rocketPowerOffSmokePosition
        #expect(abs(position.x - 2750.33) < 0.001)
        #expect(abs(position.y - 521.5) < 0.001)
    }

    @Test("Rocket power-off smoke node animates a single sprite from four frames")
    func rocketPowerOffSmokeNodeContract() {
        let smoke = RocketPowerOffSmokeNode()

        #expect(smoke.name == "rocket-power-off-smoke")
        #expect(smoke.children.count == 1)
        #expect(smoke.children.first === smoke.artworkSprite)
        #expect(smoke.artworkSprite.name == "rocket-power-off-smoke-artwork")
        #expect(smoke.animationFrameCount == 4)
        #expect(smoke.artworkSize.width > 0)
        #expect(smoke.artworkSize.height > 0)
        #expect(abs(smoke.artworkSprite.size.width - smoke.artworkSize.width * RocketPowerOffSmokeNode.displayScale) < 0.001)
        #expect(abs(smoke.artworkSprite.size.height - smoke.artworkSize.height * RocketPowerOffSmokeNode.displayScale) < 0.001)
        #expect(smoke.artworkSprite.xScale == 1)
        #expect(smoke.artworkSprite.yScale == 1)
        #expect(smoke.isHidden)
        #expect(!smoke.isEffectActive)

        smoke.setEffectActive(true)
        #expect(!smoke.isHidden)
        #expect(smoke.isEffectActive)
        #expect(smoke.artworkSprite.action(forKey: RocketPowerOffSmokeNode.animationActionKey) != nil)

        smoke.setEffectActive(false)
        #expect(smoke.isHidden)
        #expect(!smoke.isEffectActive)
        #expect(smoke.artworkSprite.action(forKey: RocketPowerOffSmokeNode.animationActionKey) == nil)
    }

    @Test("Rocket power-off smoke appears only for dark or broken engine power states")
    func rocketPowerOffSmokeVisibilityFollowsPowerState() throws {
        let offScene = makeScene(powerState: .off)
        offScene.createShipMap()
        offScene.createRocketPowerOffSmoke()
        let offSmoke = try #require(offScene.rocketPowerOffSmokeNode)
        #expect(abs(offSmoke.position.x - MapGeometryConfiguration.drawingSpaceDefault.rocketPowerOffSmokePosition.x) < 0.001)
        #expect(abs(offSmoke.position.y - MapGeometryConfiguration.drawingSpaceDefault.rocketPowerOffSmokePosition.y) < 0.001)
        #expect(offSmoke.isEffectActive)
        #expect(!offSmoke.isHidden)

        offScene.sessionState.storySystem.restore(makeStory(powerState: .basicPower))
        offScene.updateStationVisibility()
        #expect(!offSmoke.isEffectActive)
        #expect(offSmoke.isHidden)

        offScene.sessionState.storySystem.restore(makeStory(powerState: .disrupted))
        offScene.updateStationVisibility()
        #expect(offSmoke.isEffectActive)
        #expect(!offSmoke.isHidden)

        let restoredScene = makeScene(powerState: .fullyRestored)
        restoredScene.createShipMap()
        restoredScene.createRocketPowerOffSmoke()
        let restoredSmoke = try #require(restoredScene.rocketPowerOffSmokeNode)
        #expect(!restoredSmoke.isEffectActive)
        #expect(restoredSmoke.isHidden)
    }

    private func makeScene(powerState: ShipPowerState) -> GameScene {
        let storySystem = StoryProgressionSystem(state: makeStory(powerState: powerState))
        let session = GameSessionState(localPlayer: PlayerState(
            id: "local", name: "Player", worldPosition: GameMapLayout.playerSpawnPosition, isConnected: true
        ), storySystem: storySystem)
        return GameScene(
            size: CGSize(width: 1_024, height: 768),
            sessionState: session,
            tacticalMapViewModel: TacticalMapViewModel(sessionState: session)
        )
    }

    private func makeStory(powerState: ShipPowerState) -> StoryState {
        var story = StoryState.initial
        switch powerState {
        case .off:
            break
        case .basicPower:
            story.completedChallengeIDs.formUnion(StoryConfiguration.laboratoryChallenges.map(\.id))
            story.completedChallengeIDs.insert(StoryConfiguration.engineInitialChallenges[0].id)
        case .disrupted:
            story.completedChallengeIDs.formUnion(StoryConfiguration.laboratoryChallenges.map(\.id))
            story.completedChallengeIDs.formUnion(StoryConfiguration.engineInitialChallenges.prefix(4).map(\.id))
        case .fullyRestored:
            story.completedChallengeIDs.formUnion(StoryConfiguration.laboratoryChallenges.map(\.id))
            story.completedChallengeIDs.formUnion(StoryConfiguration.engineInitialChallenges.map(\.id))
            story.completedChallengeIDs.formUnion(StoryConfiguration.storageChallenges.map(\.id))
            story.completedChallengeIDs.formUnion(StoryConfiguration.engineFinalChallenges.map(\.id))
        }
        switch powerState {
        case .off:
            story.engineProgress = 0
        case .basicPower:
            story.engineProgress = 10
        case .disrupted:
            story.engineProgress = 40
        case .fullyRestored:
            story.engineProgress = 100
        }
        story.powerState = powerState
        return story
    }
}

@Suite("Lab Monitor 1")
@MainActor
struct LabMonitor1Tests {
    @Test("Lab Monitor 1 position derived from object-lab-monitor-1 with offset y+6")
    func labMonitor1Coordinate() {
        let configuration = MapGeometryConfiguration.drawingSpaceDefault
        let anchor = configuration.objects.first { $0.id == "object-lab-monitor-1" }
        #expect(anchor != nil)
        #expect(configuration.labMonitor1Position == CGPoint(
            x: anchor?.position.x ?? .zero,
            y: (anchor?.position.y ?? .zero) + 6
        ))
    }

    @Test("Lab Monitor 1 sprite uses one shader-backed sprite and follows the interaction radius")
    func labMonitor1ProximityHighlight() {
        let session = makeSession()
        session.beginGameplay()
        _ = session.handle(.roomEntered(.laboratory))
        let mapViewModel = TacticalMapViewModel(sessionState: session)
        let scene = GameScene(
            size: CGSize(width: 1_024, height: 768),
            sessionState: session,
            tacticalMapViewModel: mapViewModel
        )
        scene.createShipMap()
        scene.createPlayer()
        scene.createLabMonitor1()
        scene.createInteractiveStations()
        scene.updateStationVisibility()

        guard let monitor = scene.labMonitor1Node else {
            Issue.record("Lab Monitor 1 node was not created")
            return
        }
        #expect(!monitor.isHidden)
        #expect(scene.stationNodes[GameScene.labMemoryRepairInteractionID] == nil)
        #expect(monitor.position == MapGeometryConfiguration.drawingSpaceDefault.labMonitor1Position)
        #expect(monitor.artworkSize == CGSize(width: 137, height: 365))
        #expect(monitor.artworkSprite.xScale == 1)
        #expect(monitor.artworkSprite.yScale == 1)
        #expect(monitor.children.count == 1)
        #expect(monitor.children.first === monitor.artworkSprite)
        #expect(monitor.artworkSprite.shader != nil)
        #expect(!monitor.isProximityHighlighted)

        scene.player.position = monitor.position
        scene.checkProximityToInteractiveObject()
        #expect(monitor.isProximityHighlighted)
        #expect(monitor.action(forKey: "lab-monitor-1-highlight-transition") != nil)
        #expect(scene.activeStationID == "lab-memory-repair")
        #expect(scene.actionButton != nil)

        scene.player.position = CGPoint(
            x: monitor.position.x + LabMonitor1Node.interactionRadius + 1,
            y: monitor.position.y
        )
        scene.checkProximityToInteractiveObject()
        #expect(!monitor.isProximityHighlighted)
        #expect(scene.activeStationID == nil)
        #expect(scene.actionButton == nil)

        monitor.removeFromParent()
        monitor.setProximityHighlighted(true, animated: false)
        let renderScene = SKScene(size: monitor.artworkSprite.size)
        monitor.position = CGPoint(x: renderScene.size.width / 2, y: renderScene.size.height / 2)
        renderScene.addChild(monitor)
        let renderView = SKView(frame: CGRect(origin: .zero, size: renderScene.size))
        renderView.allowsTransparency = true
        renderView.presentScene(renderScene)
        #expect(renderView.texture(from: monitor) != nil)
    }

    @Test("Lab monitor 1 has no highlight when objective is not active")
    func labMonitor1NoHighlightWithoutObjective() {
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
        scene.createLabMonitor1()
        scene.updateStationVisibility()
        guard let monitor = scene.labMonitor1Node else {
            Issue.record("Lab Monitor 1 node was not created")
            return
        }
        #expect(monitor.isHidden)
        scene.player.position = monitor.position
        scene.checkProximityToInteractiveObject()
        #expect(!monitor.isProximityHighlighted)
        #expect(scene.actionButton == nil)
    }

    @Test("Hidden lab monitor 1 clears highlight")
    func labMonitor1HiddenClearsHighlight() {
        let session = makeSession()
        session.beginGameplay()
        _ = session.handle(.roomEntered(.laboratory))
        for id in ["lab-memory-repair", "lab-scanner-repair"] { validate(id, in: session) }
        let mapViewModel = TacticalMapViewModel(sessionState: session)
        let scene = GameScene(
            size: CGSize(width: 1_024, height: 768),
            sessionState: session,
            tacticalMapViewModel: mapViewModel
        )
        scene.createPlayer()
        scene.createLabMonitor1()
        guard let monitor = scene.labMonitor1Node else {
            Issue.record("Lab Monitor 1 node was not created")
            return
        }
        monitor.isHidden = true
        scene.checkProximityToInteractiveObject()
        #expect(!monitor.isProximityHighlighted)
    }

    @Test("lab-memory-repair is not created as an orange rectangle station node")
    func stationLabMemoryRepairNotCreated() {
        let session = makeSession()
        session.beginGameplay()
        let mapViewModel = TacticalMapViewModel(sessionState: session)
        let scene = GameScene(
            size: CGSize(width: 1_024, height: 768),
            sessionState: session,
            tacticalMapViewModel: mapViewModel
        )
        scene.createShipMap()
        scene.createInteractiveStations()
        #expect(scene.stationNodes[GameScene.labMemoryRepairInteractionID] == nil)
    }

    private func makeSession() -> GameSessionState {
        GameSessionState(localPlayer: PlayerState(
            id: "local", name: "Player", worldPosition: GameMapLayout.playerSpawnPosition, isConnected: true
        ))
    }

    private func validate(_ id: String, in session: GameSessionState) {
        guard let prompt = session.storySystem.currentPrompt(for: id) else { return }
        _ = session.handle(.drawingValidated(
            objectiveID: id,
            result: RecognitionResult(label: prompt.expectedLabel, confidence: 1, alternatives: [])
        ))
    }
}

// MARK: - Engine Monitor

@Suite("Engine Monitor")
@MainActor
struct EngineMonitorTests {
    @Test("Engine Monitor position derived from object-engine-starboard-equipment")
    func engineMonitorCoordinate() {
        let configuration = MapGeometryConfiguration.drawingSpaceDefault
        let anchor = configuration.objects.first { $0.id == "object-engine-starboard-equipment" }
        #expect(anchor != nil)
        #expect(configuration.engineMonitorPosition == CGPoint(
            x: anchor?.position.x ?? .zero,
            y: anchor?.position.y ?? .zero
        ))
    }

    @Test("Engine Monitor sprite uses one shader-backed sprite and follows the interaction radius")
    func engineMonitorProximityHighlight() {
        let session = makeSession()
        session.beginGameplay()
        _ = session.handle(.roomEntered(.engine))
        validate("engine-ignition-coil", in: session)
        let mapViewModel = TacticalMapViewModel(sessionState: session)
        let scene = GameScene(
            size: CGSize(width: 1_024, height: 768),
            sessionState: session,
            tacticalMapViewModel: mapViewModel
        )
        scene.createShipMap()
        scene.createPlayer()
        scene.createInteractiveStations()
        scene.createEngineMonitor()
        scene.updateStationVisibility()

        guard let monitor = scene.engineMonitorNode else {
            Issue.record("Engine Monitor node was not created")
            return
        }
        #expect(!monitor.isHidden)
        for id in GameScene.replacedEngineStationIDs {
            #expect(scene.stationNodes[id] == nil)
        }
        #expect(monitor.position == MapGeometryConfiguration.drawingSpaceDefault.engineMonitorPosition)
        #expect(monitor.artworkSize == CGSize(width: 414, height: 247))
        #expect(monitor.artworkSprite.xScale == 1)
        #expect(monitor.artworkSprite.yScale == 1)
        #expect(monitor.children.count == 1)
        #expect(monitor.children.first === monitor.artworkSprite)
        #expect(monitor.artworkSprite.shader != nil)
        #expect(!monitor.isProximityHighlighted)

        scene.player.position = monitor.position
        scene.checkProximityToInteractiveObject()
        #expect(monitor.isProximityHighlighted)
        #expect(monitor.action(forKey: "engine-monitor-highlight-transition") != nil)
        #expect(scene.activeStationID == "engine-ignition-coil")
        #expect(scene.actionButton != nil)

        scene.player.position = CGPoint(
            x: monitor.position.x + EngineMonitorNode.interactionRadius + 1,
            y: monitor.position.y
        )
        scene.checkProximityToInteractiveObject()
        #expect(!monitor.isProximityHighlighted)
        #expect(scene.activeStationID == nil)
        #expect(scene.actionButton == nil)
    }

    @Test("Engine Monitor has no highlight when no objective is active")
    func engineMonitorNoHighlightWithoutObjective() {
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
        scene.createEngineMonitor()
        scene.updateStationVisibility()
        guard let monitor = scene.engineMonitorNode else {
            Issue.record("Engine Monitor node was not created")
            return
        }
        #expect(monitor.isHidden)
        scene.player.position = monitor.position
        scene.checkProximityToInteractiveObject()
        #expect(!monitor.isProximityHighlighted)
        #expect(scene.actionButton == nil)
    }

    @Test("Hidden engine monitor clears highlight")
    func engineMonitorHiddenClearsHighlight() {
        let session = makeSession()
        session.beginGameplay()
        _ = session.handle(.roomEntered(.engine))
        validate("engine-ignition-coil", in: session)
        let mapViewModel = TacticalMapViewModel(sessionState: session)
        let scene = GameScene(
            size: CGSize(width: 1_024, height: 768),
            sessionState: session,
            tacticalMapViewModel: mapViewModel
        )
        scene.createShipMap()
        scene.createPlayer()
        scene.createEngineMonitor()
        scene.updateStationVisibility()
        guard let monitor = scene.engineMonitorNode else {
            Issue.record("Engine Monitor node was not created")
            return
        }
        monitor.isHidden = true
        scene.checkProximityToInteractiveObject()
        #expect(!monitor.isProximityHighlighted)
    }

    @Test("Replaced engine stations are not created as orange rectangle station nodes")
    func replacedEngineStationsNotCreated() {
        let session = makeSession()
        session.beginGameplay()
        let mapViewModel = TacticalMapViewModel(sessionState: session)
        let scene = GameScene(
            size: CGSize(width: 1_024, height: 768),
            sessionState: session,
            tacticalMapViewModel: mapViewModel
        )
        scene.createShipMap()
        scene.createInteractiveStations()
        for id in GameScene.replacedEngineStationIDs {
            #expect(scene.stationNodes[id] == nil)
        }
    }

    private func makeSession() -> GameSessionState {
        GameSessionState(localPlayer: PlayerState(
            id: "local", name: "Player", worldPosition: GameMapLayout.playerSpawnPosition, isConnected: true
        ))
    }

    private func validate(_ id: String, in session: GameSessionState) {
        guard let prompt = session.storySystem.currentPrompt(for: id) else { return }
        _ = session.handle(.drawingValidated(
            objectiveID: id,
            result: RecognitionResult(label: prompt.expectedLabel, confidence: 1, alternatives: [])
        ))
    }
}
