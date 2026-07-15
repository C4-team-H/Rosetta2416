import PencilKit
import Testing
@testable import GameClassification

private struct FixedRecognizer: DoodleRecognizer {
    let result: RecognitionResult

    func recognize(_ drawing: PKDrawing) async throws -> RecognitionResult { result }
}

@Suite("Story integration")
@MainActor
struct StoryIntegrationTests {
    @Test("Room entry through drawing authority updates objective, persistence, map, and HUD projection")
    func objectivePipeline() async throws {
        let repository = InMemoryStoryProgressRepository()
        let session = makeSession(repository: repository)
        session.beginGameplay()
        _ = session.handle(.roomEntered(.laboratory))
        let authority = LocalStoryAuthority(
            sessionState: session,
            recognizer: FixedRecognizer(result: RecognitionResult(label: "radio", confidence: 0.95, alternatives: []))
        )
        let commandID = UUID()
        let command = StoryCommand.submitDrawing(
            commandID: commandID,
            objectiveID: "lab-terminal-repair",
            drawingData: PKDrawing().dataRepresentation(),
            playerID: "local"
        )

        let result = await authority.execute(command)
        let duplicate = await authority.execute(command)
        await Task.yield()
        await Task.yield()

        #expect(result.accepted)
        #expect(!duplicate.accepted)
        #expect(session.sharedStory.intelligence == 20)
        #expect(session.progress.intelligence == 20)
        #expect(session.stats.successfulDrawings == 1)
        #expect(session.objectives.first(where: { $0.id == "lab-terminal-repair" })?.status == .completed)
        #expect(TacticalMapMarkerFactory.make(story: session.storySystem).contains {
            $0.id == "station-lab-terminal-repair" && $0.status == .completed
        })
        #expect(try await repository.load()?.latest.sharedStory.completedObjectiveIDs.contains("lab-terminal-repair") == true)
    }

    @Test("Food restores only local Energy and never story bars or objectives")
    func foodIsolation() async {
        let session = makeSession()
        session.beginGameplay()
        session.updateEnergy(deltaTime: 100, isMoving: false)
        let before = session.sharedStory
        let authority = LocalStoryAuthority(
            sessionState: session,
            recognizer: FixedRecognizer(result: RecognitionResult(label: "apple", confidence: 1, alternatives: []))
        )

        let result = await authority.execute(.submitDrawing(
            commandID: UUID(),
            objectiveID: "kitchen-apple",
            drawingData: PKDrawing().dataRepresentation(),
            playerID: "local"
        ))

        #expect(result.accepted)
        #expect(session.energy == 100)
        #expect(session.sharedStory.intelligence == before.intelligence)
        #expect(session.sharedStory.engineProgress == before.engineProgress)
        #expect(session.sharedStory.completedObjectiveIDs == before.completedObjectiveIDs)
        #expect(session.stats.kitchenRestores == 1)
    }

    @Test("Game Over retry rolls story back to checkpoint and restores minimum Energy")
    func checkpointRetry() {
        let session = makeSession()
        session.beginGameplay()
        _ = session.handle(.roomEntered(.laboratory))
        _ = session.handle(.drawingValidated(
            objectiveID: "lab-terminal-repair",
            result: RecognitionResult(label: "radio", confidence: 1, alternatives: [])
        ))
        #expect(session.sharedStory.completedObjectiveIDs.contains("lab-terminal-repair"))

        session.updateEnergy(deltaTime: 10_000, isMoving: true)
        #expect(session.phase == .gameOver)

        session.retryCheckpoint()
        #expect(session.phase == .playing)
        #expect(!session.sharedStory.completedObjectiveIDs.contains("lab-terminal-repair"))
        #expect(session.sharedStory.currentChapter == .laboratory)
        #expect(session.energy >= 50)
        #expect(session.localPlayer.worldPosition == GameMapLayout.safeSpawn(for: .laboratory))
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
}
