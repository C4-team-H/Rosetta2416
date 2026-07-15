import SpriteKit
import Testing
@testable import GameClassification

@Suite("Ship lighting")
@MainActor
struct LightingSystemTests {
    @Test("Engine 10 turns the vignette off and brightens the map")
    func basicPowerReward() {
        let scene = makeScene()
        let lighting = LightingSystem()

        lighting.apply(.basicPower, to: scene)

        #expect(abs((scene.candleLight?.alpha ?? -1) - 0) < 0.001)
        #expect(abs((scene.gridContainer?.alpha ?? -1) - 0.28) < 0.001)
    }

    @Test("Engine 40 restores the vignette and dark map")
    func disruptionRestoresFlashlight() {
        let scene = makeScene()
        let lighting = LightingSystem()
        lighting.apply(.basicPower, to: scene)

        lighting.apply(.disrupted, to: scene)

        #expect(abs((scene.candleLight?.alpha ?? -1) - 1) < 0.001)
        #expect(abs((scene.gridContainer?.alpha ?? -1) - 1) < 0.001)
    }

    private func makeScene() -> GameScene {
        let session = GameSessionState(
            localPlayer: PlayerState(
                id: "lighting-test-player",
                name: "Player",
                worldPosition: GameMapLayout.playerSpawnPosition,
                isConnected: true
            )
        )
        let map = TacticalMapViewModel(sessionState: session)
        let scene = GameScene(size: CGSize(width: 844, height: 390), sessionState: session, tacticalMapViewModel: map)
        scene.candleLight = CandleLightNode(sceneSize: scene.size)
        scene.gridContainer = SKNode()
        return scene
    }
}
