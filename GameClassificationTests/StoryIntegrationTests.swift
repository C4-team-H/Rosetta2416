import PencilKit
import Testing
@testable import GameClassification

private struct FixedRecognizer: DoodleRecognizer {
    let label: String

    func recognize(_ drawing: PKDrawing) async throws -> RecognitionResult {
        RecognitionResult(label: label, confidence: 0.95, alternatives: [])
    }
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
        
        let objectiveID = "lab-easel"
        
        for _ in 0..<2 {
            guard let prompt = session.storySystem.currentEaselPrompt(for: objectiveID) else {
                Issue.record("No prompt")
                return
            }
            let authority = LocalStoryAuthority(
                sessionState: session,
                recognizer: FixedRecognizer(label: prompt.expectedLabel)
            )
            let result = await authority.execute(.submitDrawing(
                commandID: UUID(),
                objectiveID: objectiveID,
                drawingData: PKDrawing().dataRepresentation(),
                playerID: "local"
            ))
            #expect(result.accepted)
        }
        
        guard let prompt = session.storySystem.currentEaselPrompt(for: objectiveID) else {
            Issue.record("No prompt")
            return
        }
        let authority = LocalStoryAuthority(
            sessionState: session,
            recognizer: FixedRecognizer(label: prompt.expectedLabel)
        )
        let commandID = UUID()
        let command = StoryCommand.submitDrawing(
            commandID: commandID,
            objectiveID: objectiveID,
            drawingData: PKDrawing().dataRepresentation(),
            playerID: "local"
        )

        let result = await authority.execute(command)
        let duplicate = await authority.execute(command)
        await Task.yield()
        await Task.yield()

        #expect(result.accepted)
        #expect(!duplicate.accepted)
        #expect(session.sharedStory.intelligence == 40)
        #expect(session.progress.intelligence == 40)
        #expect(session.stats.successfulDrawings == 3)
        #expect(session.objectives.first(where: { $0.id == objectiveID })?.status == .completed)
        #expect(TacticalMapMarkerFactory.make(story: session.storySystem).contains {
            $0.id == "station-\(objectiveID)" && $0.status == .completed
        })
        #expect(try await repository.load()?.latest.sharedStory.completedObjectiveIDs.contains(objectiveID) == true)
    }

    @Test("Food restores only local Energy and never story bars or objectives")
    func foodIsolation() async {
        let session = makeSession()
        session.beginGameplay()
        session.updateEnergy(deltaTime: 100, isMoving: false)
        let before = session.sharedStory
        let authority = LocalStoryAuthority(
            sessionState: session,
            recognizer: FixedRecognizer(label: "apple")
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
        
        let objectiveID = "lab-easel"
        for _ in 0..<3 {
            guard let prompt = session.storySystem.currentEaselPrompt(for: objectiveID) else {
                Issue.record("No prompt")
                return
            }
            _ = session.handle(.drawingValidated(
                objectiveID: objectiveID,
                result: RecognitionResult(label: prompt.expectedLabel, confidence: 1, alternatives: [])
            ))
        }
        #expect(session.sharedStory.completedObjectiveIDs.contains(objectiveID))

        session.updateEnergy(deltaTime: 10_000, isMoving: true)
        #expect(session.phase == .gameOver)

        session.retryCheckpoint()
        #expect(session.phase == .playing)
        #expect(!session.sharedStory.completedObjectiveIDs.contains(objectiveID))
        #expect(session.sharedStory.currentChapter == .laboratory)
        #expect(session.energy >= 50)
        #expect(session.localPlayer.worldPosition == GameMapLayout.safeSpawn(for: .laboratory))
    }

    @Test("New Game resets story, survival, statistics, position, and persisted progress")
    func newGameReset() async throws {
        let repository = InMemoryStoryProgressRepository()
        let session = makeSession(repository: repository)
        session.beginGameplay()
        _ = session.handle(.roomEntered(.laboratory))
        
        let objectiveID = "lab-easel"
        guard let prompt = session.storySystem.currentEaselPrompt(for: objectiveID) else {
            Issue.record("No prompt")
            return
        }
        _ = session.handle(.drawingValidated(
            objectiveID: objectiveID,
            result: RecognitionResult(label: prompt.expectedLabel, confidence: 1, alternatives: [])
        ))
        session.beginDrawing(objectiveID: objectiveID)
        session.endDrawing()
        session.updateEnergy(deltaTime: 100, isMoving: true)

        session.startNewSession()
        await Task.yield()
        await Task.yield()

        #expect(session.phase == .playing)
        #expect(session.sharedStory.currentChapter == .sleepingRoom)
        #expect(session.sharedStory.completedObjectiveIDs.isEmpty)
        #expect(session.sharedStory.intelligence == 10)
        #expect(session.sharedStory.engineProgress == 0)
        #expect(session.sharedStory.powerState == .emergency)
        #expect(session.energy == 100)
        #expect(session.stats == GameSessionStats())
        #expect(session.localPlayer.worldPosition == GameMapLayout.playerSpawnPosition)

        let saved = try await repository.load()
        #expect(saved?.latest.sharedStory.currentChapter == .sleepingRoom)
        #expect(saved?.latest.sharedStory.completedObjectiveIDs.isEmpty == true)
        #expect(saved?.latest.localSurvival.energy == 100)
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
