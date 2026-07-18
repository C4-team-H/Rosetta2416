import Foundation
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

    @Test("Flashlight center follows the physics-resolved player without camera lag")
    func flashlightFollowsPlayer() {
        let scene = makeScene()
        scene.addChild(scene.cameraNode)
        scene.camera = scene.cameraNode
        scene.cameraNode.setScale(1)
        scene.cameraNode.position = CGPoint(x: 120, y: 90)

        let player = PlayerNode(configuration: GameMapLayout.ship.configuration, debugEnabled: false)
        player.position = CGPoint(x: 180, y: 130)
        scene.player = player
        scene.addChild(player)

        let light = scene.candleLight!
        light.position = CGPoint(x: -scene.size.width / 2, y: -scene.size.height / 2)
        scene.cameraNode.addChild(light)

        scene.synchronizeCandleLightWithPlayer()

        let expected = light.convert(player.position, from: scene)
        #expect(abs(light.lightPosition.x - expected.x) < 0.001)
        #expect(abs(light.lightPosition.y - expected.y) < 0.001)

        player.position = CGPoint(x: 260, y: 205)
        scene.synchronizeCandleLightWithPlayer()

        let movedExpected = light.convert(player.position, from: scene)
        #expect(abs(light.lightPosition.x - movedExpected.x) < 0.001)
        #expect(abs(light.lightPosition.y - movedExpected.y) < 0.001)
    }

    #if DEBUG
    @Test("Map debug mode hides candle and transient lighting overlays")
    func debugModeDisablesLightingOverlay() throws {
        let defaultsName = "LightingSystemTests.Debug.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: defaultsName))
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let settings = GameDebugSettings(defaults: defaults)
        let scene = makeScene(debugSettings: settings)
        let flash = SKNode()
        flash.name = "lightingFlashOverlay"
        scene.cameraNode.addChild(flash)

        settings.isMapDebugEnabled = true
        scene.synchronizeDebugLightingVisibility()

        #expect(scene.candleLight?.isHidden == true)
        #expect(scene.cameraNode.childNode(withName: "lightingFlashOverlay") == nil)

        settings.isMapDebugEnabled = false
        scene.synchronizeDebugLightingVisibility()
        #expect(scene.candleLight?.isHidden == false)
    }
    #endif

    private func makeScene(debugSettings: GameDebugSettings? = nil) -> GameScene {
        let session = GameSessionState(
            localPlayer: PlayerState(
                id: "lighting-test-player",
                name: "Player",
                worldPosition: GameMapLayout.playerSpawnPosition,
                isConnected: true
            )
        )
        let map = TacticalMapViewModel(sessionState: session)
        let scene = GameScene(
            size: CGSize(width: 844, height: 390),
            sessionState: session,
            tacticalMapViewModel: map,
            debugSettings: debugSettings
        )
        scene.candleLight = CandleLightNode(sceneSize: scene.size)
        scene.gridContainer = SKNode()
        return scene
    }
}
