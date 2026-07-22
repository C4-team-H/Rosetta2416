import Foundation
import SpriteKit
import Testing
@testable import Rosetta

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

    @Test("Candle overlay darkens interactive furniture while camera HUD stays visible")
    func candleOverlayCoversAlbumBook() throws {
        let scene = makeScene()
        scene.sessionState.beginGameplay()
        scene.addChild(scene.cameraNode)
        scene.camera = scene.cameraNode
        scene.createShipMap()
        scene.createPlayer()
        scene.createAlbumBook()
        scene.createJoystick()
        scene.enableCandleLight()

        let shipMap = try #require(scene.shipMapNode)
        let albumBook = try #require(scene.albumBookNode)
        let candleLight = try #require(scene.candleLight)

        scene.player.position = albumBook.position
        scene.checkProximityToAlbumBook()
        let albumButton = try #require(scene.albumBookButton)

        let albumBookWorldZ = shipMap.zPosition
            + shipMap.furnitureLayer.zPosition
            + albumBook.zPosition
        let candleWorldZ = scene.cameraNode.zPosition + candleLight.zPosition
        let joystickWorldZ = scene.cameraNode.zPosition + scene.joystickBase.zPosition
        let albumButtonWorldZ = scene.cameraNode.zPosition + albumButton.zPosition

        #expect(scene.cameraNode.zPosition == GameScene.cameraOverlayRootZ)
        #expect(albumBookWorldZ < candleWorldZ)
        #expect(candleWorldZ < joystickWorldZ)
        #expect(candleWorldZ < albumButtonWorldZ)
    }

    @Test("Candle overlay also covers the kitchen table object")
    func candleOverlayCoversKitchenTableFoodStation() throws {
        let scene = makeScene()
        scene.sessionState.beginGameplay()
        scene.addChild(scene.cameraNode)
        scene.camera = scene.cameraNode
        scene.createShipMap()
        scene.createPlayer()
        scene.createFoodObject()
        scene.createJoystick()
        scene.enableCandleLight()

        let shipMap = try #require(scene.shipMapNode)
        let table = try #require(scene.foodObject)
        let candleLight = try #require(scene.candleLight)

        let tableWorldZ = shipMap.zPosition
            + shipMap.furnitureLayer.zPosition
            + table.zPosition
        let candleWorldZ = scene.cameraNode.zPosition + candleLight.zPosition
        let joystickWorldZ = scene.cameraNode.zPosition + scene.joystickBase.zPosition

        #expect(scene.cameraNode.zPosition == GameScene.cameraOverlayRootZ)
        #expect(tableWorldZ < candleWorldZ)
        #expect(candleWorldZ < joystickWorldZ)
    }

    @Test("Candle overlay also covers the lab table object")
    func candleOverlayCoversLabTable() throws {
        let scene = makeScene()
        scene.sessionState.beginGameplay()
        scene.addChild(scene.cameraNode)
        scene.camera = scene.cameraNode
        scene.createShipMap()
        scene.createPlayer()
        scene.createLabTable()
        scene.createJoystick()
        scene.enableCandleLight()

        let shipMap = try #require(scene.shipMapNode)
        let labTable = try #require(scene.labTableNode)
        let candleLight = try #require(scene.candleLight)

        let labTableWorldZ = shipMap.zPosition
            + shipMap.furnitureLayer.zPosition
            + labTable.zPosition
        let candleWorldZ = scene.cameraNode.zPosition + candleLight.zPosition
        let joystickWorldZ = scene.cameraNode.zPosition + scene.joystickBase.zPosition

        #expect(scene.cameraNode.zPosition == GameScene.cameraOverlayRootZ)
        #expect(labTableWorldZ < candleWorldZ)
        #expect(candleWorldZ < joystickWorldZ)
    }

    @Test("Candle overlay also covers the lab monitor 2 object")
    func candleOverlayCoversLabMonitor2() throws {
        let scene = makeScene()
        scene.sessionState.beginGameplay()
        scene.addChild(scene.cameraNode)
        scene.camera = scene.cameraNode
        scene.createShipMap()
        scene.createPlayer()
        scene.createLabMonitor2()
        scene.createJoystick()
        scene.enableCandleLight()

        let shipMap = try #require(scene.shipMapNode)
        let monitor = try #require(scene.labMonitor2Node)
        let candleLight = try #require(scene.candleLight)

        let monitorWorldZ = shipMap.zPosition
            + shipMap.furnitureLayer.zPosition
            + monitor.zPosition
        let candleWorldZ = scene.cameraNode.zPosition + candleLight.zPosition
        let joystickWorldZ = scene.cameraNode.zPosition + scene.joystickBase.zPosition

        #expect(scene.cameraNode.zPosition == GameScene.cameraOverlayRootZ)
        #expect(monitorWorldZ < candleWorldZ)
        #expect(candleWorldZ < joystickWorldZ)
    }

    @Test("Candle overlay also covers the lab monitor 1 object")
    func candleOverlayCoversLabMonitor1() throws {
        let scene = makeScene()
        scene.sessionState.beginGameplay()
        scene.addChild(scene.cameraNode)
        scene.camera = scene.cameraNode
        scene.createShipMap()
        scene.createPlayer()
        scene.createLabMonitor1()
        scene.createJoystick()
        scene.enableCandleLight()

        let shipMap = try #require(scene.shipMapNode)
        let monitor = try #require(scene.labMonitor1Node)
        let candleLight = try #require(scene.candleLight)

        let monitorWorldZ = shipMap.zPosition
            + shipMap.furnitureLayer.zPosition
            + monitor.zPosition
        let candleWorldZ = scene.cameraNode.zPosition + candleLight.zPosition
        let joystickWorldZ = scene.cameraNode.zPosition + scene.joystickBase.zPosition

        #expect(scene.cameraNode.zPosition == GameScene.cameraOverlayRootZ)
        #expect(monitorWorldZ < candleWorldZ)
        #expect(candleWorldZ < joystickWorldZ)
    }

    @Test("Candle overlay also covers the rocket power-off smoke effect")
    func candleOverlayCoversRocketPowerOffSmoke() throws {
        let scene = makeScene()
        scene.sessionState.beginGameplay()
        scene.addChild(scene.cameraNode)
        scene.camera = scene.cameraNode
        scene.createShipMap()
        scene.createRocketPowerOffSmoke()
        scene.createJoystick()
        scene.enableCandleLight()

        let shipMap = try #require(scene.shipMapNode)
        let smoke = try #require(scene.rocketPowerOffSmokeNode)
        let candleLight = try #require(scene.candleLight)

        let smokeWorldZ = shipMap.zPosition
            + shipMap.furnitureLayer.zPosition
            + smoke.zPosition
        let candleWorldZ = scene.cameraNode.zPosition + candleLight.zPosition
        let joystickWorldZ = scene.cameraNode.zPosition + scene.joystickBase.zPosition

        #expect(scene.cameraNode.zPosition == GameScene.cameraOverlayRootZ)
        #expect(smokeWorldZ < candleWorldZ)
        #expect(candleWorldZ < joystickWorldZ)
    }

    @Test("Engine restoration leaves Cockpit displays off until Victory")
    func cockpitDisplaysWaitForVictory() {
        let scene = makeScene()
        let lighting = LightingSystem()

        lighting.apply(.fullyRestored, to: scene)
        #expect(scene.childNode(withName: "cockpitDisplayGlow") == nil)

        lighting.playVictory(in: scene)
        #expect(scene.childNode(withName: "cockpitDisplayGlow") != nil)
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
