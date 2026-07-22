import SpriteKit
import Testing
@testable import Rosetta

@Suite("Play Again scene replacement")
@MainActor
struct PlayAgainRegressionTests {
    @Test("Old GameScene.willMove does not clobber phase when replaced by another GameScene (playAgain flow)")
    func willMoveSkipsEndGameplayWhenReplacedByGameScene() {
        let session = GameSessionState(localPlayer: PlayerState(
            id: "play-again-player",
            name: "Player",
            worldPosition: GameMapLayout.playerSpawnPosition,
            isConnected: true
        ))

        let view = SKView(frame: CGRect(x: 0, y: 0, width: 1_024, height: 768))
        let oldScene = GameScene(
            size: view.bounds.size,
            sessionState: session,
            tacticalMapViewModel: TacticalMapViewModel(sessionState: session)
        )
        view.presentScene(oldScene)
        session.beginGameplay()
        #expect(session.phase == .playing)

        let newScene = GameScene(
            size: view.bounds.size,
            sessionState: session,
            tacticalMapViewModel: TacticalMapViewModel(sessionState: session)
        )

        // Simulate playAgain: present a new GameScene with a fade transition.
        // SpriteKit updates view.scene immediately and calls newScene.didMove
        // immediately, but delays oldScene.willMove until the transition ends.
        view.presentScene(newScene, transition: .fade(withDuration: 0.8))
        #expect(view.scene === newScene)

        // Simulate the transition completing: the old scene is removed.
        // This is the moment SpriteKit calls willMove(from:) on the old scene.
        oldScene.willMove(from: view)

        // The phase must remain .playing — the new game scene owns the session.
        // Before the fix, endGameplay() ran here and reset phase to .preparing,
        // freezing the game (no HUD, no energy drain, no progression).
        #expect(session.phase == .playing, "playAgain left phase as \(session.phase) — game is frozen")
    }

    @Test("Old GameScene.willMove still ends gameplay when replaced by a non-GameScene (main menu flow)")
    func willMoveEndsGameplayWhenReplacedByNonGameScene() {
        let session = GameSessionState(localPlayer: PlayerState(
            id: "main-menu-player",
            name: "Player",
            worldPosition: GameMapLayout.playerSpawnPosition,
            isConnected: true
        ))

        let view = SKView(frame: CGRect(x: 0, y: 0, width: 1_024, height: 768))
        let oldScene = GameScene(
            size: view.bounds.size,
            sessionState: session,
            tacticalMapViewModel: TacticalMapViewModel(sessionState: session)
        )
        view.presentScene(oldScene)
        session.beginGameplay()
        #expect(session.phase == .playing)

        // Present a plain SKScene to simulate returning to a non-game screen
        // (e.g. MainMenuScene). view.scene is no longer a GameScene.
        view.presentScene(SKScene(size: view.bounds.size), transition: .fade(withDuration: 0.6))
        #expect(view.scene is GameScene == false)

        oldScene.willMove(from: view)

        // When replaced by a non-game scene, endGameplay() should still fire
        // so the session phase resets to .preparing.
        #expect(session.phase == .preparing)
    }

    @Test("Victory launch scene keeps the gameplay session alive until its cutscene completes")
    func victoryLaunchSceneKeepsSessionAlive() {
        let session = GameSessionState(localPlayer: PlayerState(
            id: "victory-cutscene-player",
            name: "Player",
            worldPosition: GameMapLayout.playerSpawnPosition,
            isConnected: true
        ))
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 1_024, height: 768))
        let oldScene = GameScene(
            size: view.bounds.size,
            sessionState: session,
            tacticalMapViewModel: TacticalMapViewModel(sessionState: session)
        )
        view.presentScene(oldScene)
        session.beginGameplay()

        let launchScene = VictoryLaunchScene(size: view.bounds.size) {}
        view.presentScene(launchScene, transition: .fade(withDuration: 0.1))
        oldScene.willMove(from: view)

        #expect(session.phase == .playing)
    }
}
