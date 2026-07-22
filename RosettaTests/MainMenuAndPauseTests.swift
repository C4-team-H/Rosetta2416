import SpriteKit
import Testing
import UIKit
@testable import Rosetta

@Suite("Main Menu & Checkpoint Save Tests")
@MainActor
struct MainMenuAndPauseTests {
    @Test("GameViewController presents the main menu on launch")
    func testGameViewControllerPresentsMainMenuOnLaunch() throws {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        let viewController = try #require(
            storyboard.instantiateInitialViewController() as? GameViewController
        )

        viewController.loadViewIfNeeded()
        let spriteView = try #require(viewController.view as? SKView)

        #expect(spriteView.scene is MainMenuScene)
    }

    @Test("Continue becomes available only after Pause Leave saves the session")
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

        // Starting and autosaving a new session must not expose Continue.
        session.startNewSession()
        #expect(session.hasSavedProgress == false)

        // Pause -> Leave explicitly exposes the saved session.
        session.saveForMainMenuContinue()
        #expect(session.hasSavedProgress == true)
        await Task.yield()
        await Task.yield()

        let returningSession = GameSessionState(
            localPlayer: PlayerState(
                id: "returning-player",
                name: "Returning",
                worldPosition: GameMapLayout.playerSpawnPosition,
                isConnected: true
            ),
            repository: repository
        )
        await returningSession.loadProgress()
        #expect(returningSession.hasSavedProgress == true)

        // Choosing Continue consumes the menu eligibility until the player leaves again.
        returningSession.resumeSavedProgress()
        #expect(returningSession.hasSavedProgress == false)

        // Clearing progress resets hasSavedProgress
        returningSession.clearSavedProgress()
        #expect(returningSession.hasSavedProgress == false)
    }

    @Test("MainMenuScene layout reflects hasSavedProgress")
    func testMainMenuSceneLayout() {
        let coordinator = GameplayCoordinator()
        let sceneSize = CGSize(width: 1024, height: 768)
        let menuScene = MainMenuScene(size: sceneSize, coordinator: coordinator)
        let view = SKView(frame: CGRect(origin: .zero, size: sceneSize))
        view.presentScene(menuScene)

        // When no saved progress, startButton (Continue) should not be in scene
        #expect(coordinator.hasSavedProgress == false)
        #expect(menuScene.childNode(withName: "startButton") == nil)
        #expect(menuScene.childNode(withName: "newGameButton") != nil)

        let starField = menuScene.childNode(withName: "mainMenuStarField")
        #expect(starField != nil)
        let stars = starField?.children.compactMap { $0 as? SKSpriteNode } ?? []
        #expect(stars.count >= 18)
        #expect(stars.allSatisfy { $0.name == "twinklingStar" })
        #expect((stars.map(\.size.width).max() ?? 0) > (stars.map(\.size.width).min() ?? 0) * 2)
        #expect(stars.allSatisfy { $0.hasActions() })

        let jetFire = menuScene.childNode(withName: MainMenuScene.jetFireNodeName) as? SKSpriteNode
        #expect(jetFire != nil)
        #expect(jetFire?.action(forKey: MainMenuScene.jetFireAnimationKey) != nil)
        #expect(jetFire?.anchorPoint == CGPoint(x: 0.5, y: 1))
        #expect(abs((jetFire?.position.x ?? 0) - sceneSize.width / 2) < 0.001)

        let singleButtonY = (menuScene.childNode(withName: "newGameButton") as? SKSpriteNode)?.position.y ?? 0
        #expect(abs(singleButtonY - sceneSize.height * 0.24) < 0.001)

        // Simulate Pause -> Leave (saved progress eligible for Continue)
        coordinator.sessionState.startNewSession()
        coordinator.sessionState.saveForMainMenuContinue()
        menuScene.updateMenuButtons()

        #expect(coordinator.hasSavedProgress == true)
        #expect(menuScene.childNode(withName: "startButton") != nil)
        #expect(menuScene.childNode(withName: "newGameButton") != nil)
        let continueButtonY = menuScene.childNode(withName: "startButton")?.position.y ?? 0
        let pairedNewGameButtonY = menuScene.childNode(withName: "newGameButton")?.position.y ?? 0
        #expect(abs(continueButtonY - sceneSize.height * 0.24) < 0.001)
        #expect(abs(pairedNewGameButtonY - sceneSize.height * 0.14) < 0.001)
    }
}
