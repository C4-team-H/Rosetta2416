import PencilKit
import Testing
import UIKit
@testable import Rosetta

private struct FixedRecognizer: DoodleRecognizer {
    let label: String
    let confidence: Double

    init(label: String, confidence: Double = 0.95) {
        self.label = label
        self.confidence = confidence
    }

    func recognize(_ drawing: PKDrawing) async throws -> RecognitionResult {
        RecognitionResult(label: label, confidence: confidence, alternatives: [])
    }
}

@Suite("Story integration")
@MainActor
struct StoryIntegrationTests {
    @Test("Physical Lab stations flow through authority, persistence, map, and HUD state")
    func objectivePipeline() async throws {
        let repository = InMemoryStoryProgressRepository()
        let session = makeSession(repository: repository)
        session.beginGameplay()
        _ = session.handle(.roomEntered(.laboratory))

        for definition in StoryConfiguration.laboratoryChallenges {
            let prompt = try #require(session.storySystem.currentPrompt(for: definition.id))
            let authority = LocalStoryAuthority(
                sessionState: session,
                recognizer: FixedRecognizer(label: prompt.expectedLabel)
            )
            let commandID = UUID()
            let command = StoryCommand.submitDrawing(
                commandID: commandID,
                objectiveID: definition.id,
                drawingData: drawingData(),
                playerID: "local"
            )
            let result = await authority.execute(command)
            let duplicate = await authority.execute(command)

            #expect(result.accepted)
            #expect(!duplicate.accepted)
        }
        await Task.yield()
        await Task.yield()

        #expect(session.sharedStory.intelligence == 40)
        #expect(session.sharedStory.currentChapter == .engineInitial)
        #expect(session.sharedStory.activeMission?.title == "Repair the Engine.")
        #expect(session.stats.successfulDrawings == 3)
        #expect(session.activeObjective?.id == "engine-ignition-coil")
        #expect(try await repository.load()?.latest.sharedStory.completedChallengeIDs
            == Set(StoryConfiguration.laboratoryChallenges.map(\.id)))
    }

    @Test("Entering Kitchen triggers Robo dialogue regarding energy restoration")
    func kitchenEntryDialogue() async {
        let session = makeSession()
        session.beginGameplay()
        while session.currentDialogue != nil {
            session.dismissDialogue()
        }
        _ = session.handle(.roomEntered(.kitchen))
        #expect(session.currentDialogue?.id == "kitchen-entered")
        #expect(session.currentDialogue?.text == "Robo: You can add your energy by draw food at the kitchen")
    }

    @Test("Kitchen restores exactly 50, clamps at 100, and never mutates story")
    func foodIsolationAndRepeatability() async {
        let session = makeSession()
        session.beginGameplay()
        session.updateEnergy(deltaTime: 200, isMoving: false)
        let before = session.sharedStory

        for label in ["apple", "apple"] {
            let authority = LocalStoryAuthority(sessionState: session, recognizer: FixedRecognizer(label: label))
            let result = await authority.execute(.submitDrawing(
                commandID: UUID(),
                objectiveID: "kitchen-\(label)",
                drawingData: drawingData(),
                playerID: "local"
            ))
            #expect(result.accepted)
        }

        #expect(session.energy == 100)
        #expect(session.sharedStory.intelligence == before.intelligence)
        #expect(session.sharedStory.engineProgress == before.engineProgress)
        #expect(session.sharedStory.completedChallengeIDs == before.completedChallengeIDs)
        #expect(session.sharedStory.activeMission == before.activeMission)
        #expect(session.stats.kitchenRestores == 2)
    }

    @Test("Empty canvas and recognizer-free cancellation path do not trigger the Album hint")
    func emptyCanvasDoesNotTriggerHint() async {
        let session = makeSession()
        session.beginGameplay()
        _ = session.handle(.roomEntered(.laboratory))
        let authority = LocalStoryAuthority(sessionState: session, recognizer: FixedRecognizer(label: "cat"))

        let result = await authority.execute(.submitDrawing(
            commandID: UUID(),
            objectiveID: "lab-memory-repair",
            drawingData: PKDrawing().dataRepresentation(),
            playerID: "local"
        ))

        #expect(!result.accepted)
        #expect(result.effects.isEmpty)
        #expect(!session.sharedStory.albumBook.hasFailedDrawingBefore)
        #expect(session.sharedStory.albumBook.isMarkerVisible)
    }

    @Test("Engine 40 disruption subtracts ten Energy exactly once")
    func disruptionPenaltyIdempotency() {
        let session = makeSession()
        session.beginGameplay()
        _ = session.handle(.roomEntered(.laboratory))
        complete(.laboratory, in: session)

        for definition in StoryConfiguration.engineInitialChallenges.prefix(4) {
            validate(definition.id, in: session)
        }
        let afterDisruption = session.energy
        #expect(afterDisruption == 90)

        let completed = StoryConfiguration.engineInitialChallenges[3]
        validate(completed.id, in: session)
        #expect(session.energy == afterDisruption)
        #expect(session.sharedStory.processedMilestoneIDs.contains("engine40"))
    }

    @Test("Game Over retries the latest checkpoint directly with minimum Energy")
    func checkpointRetry() {
        let session = makeSession()
        session.beginGameplay()
        _ = session.handle(.roomEntered(.laboratory))
        let checkpointLabels = session.sharedStory.selectedChallengeLabels
        validate("lab-memory-repair", in: session)
        #expect(session.sharedStory.completedChallengeIDs.contains("lab-memory-repair"))

        session.updateEnergy(deltaTime: 10_000, isMoving: true)
        #expect(session.phase == .gameOver)
        session.retryCheckpoint()

        #expect(session.phase == .playing)
        #expect(!session.sharedStory.completedChallengeIDs.contains("lab-memory-repair"))
        #expect(session.sharedStory.currentChapter == .laboratory)
        #expect(session.energy >= 50)
        #expect(session.localPlayer.worldPosition == GameMapLayout.safeSpawn(for: .laboratoryEntered))
        #expect(session.sharedStory.selectedChallengeLabels == checkpointLabels)
    }

    @Test("New Game resets the canonical session and persistence")
    func newGameReset() async throws {
        let repository = InMemoryStoryProgressRepository()
        let session = makeSession(repository: repository)
        session.beginGameplay()
        _ = session.handle(.roomEntered(.laboratory))
        validate("lab-memory-repair", in: session)
        session.updateEnergy(deltaTime: 100, isMoving: true)

        session.startNewSession()
        await Task.yield()
        await Task.yield()

        #expect(session.phase == .playing)
        #expect(session.sharedStory.currentChapter == .sleepingRoom)
        #expect(session.sharedStory.completedChallengeIDs.isEmpty)
        #expect(session.sharedStory.intelligence == 10)
        #expect(session.sharedStory.engineProgress == 0)
        #expect(session.sharedStory.powerState == .off)
        #expect(session.energy == 100)
        #expect(session.stats == GameSessionStats())
        #expect(session.localPlayer.worldPosition == GameMapLayout.safeSpawn(for: .sleepingRoomStart))
        let persisted = try await repository.load()?.latest.sharedStory
        #expect(persisted?.currentChapter == .sleepingRoom)
        #expect(persisted?.completedChallengeIDs.isEmpty == true)
        #expect(persisted?.deliveredDialogueIDs == ["intro-1"])
    }

    @Test("Continue Game is available only after the player leaves from pause")
    func continueGameAvailability() async throws {
        let repository = InMemoryStoryProgressRepository()
        let firstSession = makeSession(repository: repository)

        #expect(!firstSession.hasSavedProgress)
        await firstSession.loadProgress()
        #expect(!firstSession.hasSavedProgress)

        firstSession.startNewSession()
        #expect(!firstSession.hasSavedProgress)
        firstSession.saveForMainMenuContinue()
        #expect(firstSession.hasSavedProgress)
        await Task.yield()
        await Task.yield()

        let returningSession = makeSession(repository: repository)
        #expect(!returningSession.hasSavedProgress)
        await returningSession.loadProgress()
        #expect(returningSession.hasSavedProgress)

        returningSession.resumeSavedProgress()
        #expect(!returningSession.hasSavedProgress)
    }

    @Test("Final mission waits for launch cutscene before showing Victory")
    func victoryWaitsForLaunchCutscene() {
        let session = makeSession()
        session.beginGameplay()
        _ = session.handle(.roomEntered(.laboratory))
        complete(.laboratory, in: session)
        complete(.engineInitial, in: session)
        complete(.storage, in: session)
        complete(.engineFinal, in: session)
        _ = session.handle(.roomEntered(.cockpit))
        complete(.cockpit, in: session)

        #expect(session.sharedStory.currentChapter == .victory)
        #expect(session.phase == .cutscene(.victoryLaunch))

        session.endCutscene()
        #expect(session.phase == .cutscene(.victoryLaunch))

        session.completeVictoryCutscene()
        #expect(session.phase == .victory)
    }

    @Test("Initial map markers immediately show active lab mission in yellow and reference album without entering lab")
    func initialMapMarkersShowLabMissionAndAlbum() {
        let session = makeSession()
        session.beginGameplay()

        let viewModel = TacticalMapViewModel(sessionState: session)
        let markers = viewModel.visibleMarkers

        let labMarker = markers.first { $0.id == "room-laboratory" }
        #expect(labMarker != nil)
        #expect(labMarker?.status == .active)

        let albumMarker = markers.first { $0.id == "album-book" }
        #expect(albumMarker != nil)
        #expect(albumMarker?.kind == .albumBook)
    }

    private func complete(_ chapter: StoryChapter, in session: GameSessionState) {
        for definition in StoryConfiguration.challenges(for: chapter) {
            validate(definition.id, in: session)
        }
    }

    private func validate(_ id: String, in session: GameSessionState) {
        guard let prompt = session.storySystem.currentPrompt(for: id) else {
            Issue.record("Missing prompt for \(id)")
            return
        }
        _ = session.handle(.drawingValidated(
            objectiveID: id,
            result: RecognitionResult(label: prompt.expectedLabel, confidence: 1, alternatives: [])
        ))
    }

    private func makeSession(repository: StoryProgressRepository? = nil) -> GameSessionState {
        GameSessionState(
            localPlayer: PlayerState(
                id: "local",
                name: "Local Player",
                worldPosition: GameMapLayout.playerSpawnPosition,
                isConnected: true
            ),
            repository: repository
        )
    }

    private func drawingData() -> Data {
        let points = [
            PKStrokePoint(
                location: CGPoint(x: 1, y: 1), timeOffset: 0, size: CGSize(width: 5, height: 5),
                opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2
            ),
            PKStrokePoint(
                location: CGPoint(x: 12, y: 12), timeOffset: 0.1, size: CGSize(width: 5, height: 5),
                opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2
            )
        ]
        let path = PKStrokePath(controlPoints: points, creationDate: .now)
        let stroke = PKStroke(ink: PKInk(.pen, color: .black), path: path)
        return PKDrawing(strokes: [stroke]).dataRepresentation()
    }
}
