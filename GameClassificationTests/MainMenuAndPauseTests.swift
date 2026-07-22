import SpriteKit
import Testing
@testable import GameClassification

@Suite("Main Menu & Checkpoint Save Tests")
@MainActor
struct MainMenuAndPauseTests {
    @Test("GameSessionState tracks hasSavedProgress correctly")
    func testHasSavedProgressTracking() async throws {
        let repository = InMemoryStoryProgressRepository()
        let session = GameSessionState(
            localPlayer: PlayerState(
                id: "test-player",
                name: "Test",
                worldPosition: GameMapLayout.playerSpawnPosition,
                isConnected: true
            ),
            repository: repository
        )

        // Initially no progress saved
        await session.loadProgress()
        #expect(session.hasSavedProgress == false)

        // After starting a new session, progress is saved
        session.startNewSession()
        #expect(session.hasSavedProgress == true)

        // Clearing progress resets hasSavedProgress
        session.clearSavedProgress()
        #expect(session.hasSavedProgress == false)
    }

    @Test("MainMenuScene layout reflects hasSavedProgress")
    func testMainMenuSceneLayout() {
        let coordinator = GameplayCoordinator()
        let menuScene = MainMenuScene(size: CGSize(width: 1024, height: 768), coordinator: coordinator)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 1024, height: 768))
        view.presentScene(menuScene)

        // When no saved progress, startButton (Continue) should not be in scene
        #expect(coordinator.hasSavedProgress == false)
        #expect(menuScene.childNode(withName: "startButton") == nil)
        #expect(menuScene.childNode(withName: "newGameButton") != nil)

        // Simulate new session (saved progress)
        coordinator.sessionState.startNewSession()
        menuScene.updateMenuButtons()

        #expect(coordinator.hasSavedProgress == true)
        #expect(menuScene.childNode(withName: "startButton") != nil)
        #expect(menuScene.childNode(withName: "newGameButton") != nil)
    }
}
