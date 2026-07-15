import SpriteKit

@MainActor
final class GameplayCoordinator {
    let sessionState: GameSessionState
    let tacticalMapViewModel: TacticalMapViewModel

    init() {
        let sessionState = GameSessionState(
            localPlayer: PlayerState(
                id: "local-player",
                name: "You",
                worldPosition: GameMapLayout.playerSpawnPosition,
                isConnected: true
            )
        )
        self.sessionState = sessionState
        tacticalMapViewModel = TacticalMapViewModel(sessionState: sessionState)
    }

    func makeMainMenuScene(size: CGSize) -> MainMenuScene {
        MainMenuScene(size: size, coordinator: self)
    }

    func makeGameScene(size: CGSize) -> GameScene {
        GameScene(size: size, sessionState: sessionState, tacticalMapViewModel: tacticalMapViewModel)
    }
}
