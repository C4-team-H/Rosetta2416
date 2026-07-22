import CoreGraphics
import SpriteKit
import Testing
@testable import Rosetta

@Suite("Joystick HUD")
@MainActor
struct JoystickHUDTests {
    @Test("Joystick uses the enlarged console control dimensions")
    func enlargedDimensions() {
        let scene = makeScene()
        scene.createJoystick()

        #expect(scene.joystickRadius == 84)
        #expect(scene.joystickKnobRadius == 38)
        #expect(scene.joystickBase.position == scene.joystickHUDPosition)
        #expect(scene.joystickBase.childNode(withName: "joystick-inner-plate") != nil)
        #expect(scene.joystickBase.childNode(withName: "joystick-active-ring") != nil)
        #expect(scene.joystickKnob.childNode(withName: "joystick-knob-face") != nil)
        #expect(scene.joystickKnob.childNode(withName: "joystick-knob-highlight") != nil)
    }

    @Test("Joystick keeps its screen-edge insets after resizing")
    func responsivePosition() {
        let scene = makeScene(size: CGSize(width: 1_024, height: 768))
        scene.createJoystick()

        let leftEdge = scene.joystickBase.position.x - scene.joystickRadius
        let bottomEdge = scene.joystickBase.position.y - scene.joystickRadius

        #expect(leftEdge == -scene.size.width / 2 + scene.joystickHorizontalInset)
        #expect(bottomEdge == -scene.size.height / 2 + scene.joystickVerticalInset)

        scene.size = CGSize(width: 844, height: 390)

        #expect(scene.joystickBase.position == scene.joystickHUDPosition)
    }

    @Test("Enlarged joystick still normalizes movement at its edge")
    func normalizedMovement() {
        let scene = makeScene()
        scene.createJoystick()

        scene.updateJoystickKnob(touchLocation: CGPoint(
            x: scene.joystickBase.position.x + scene.joystickRadius,
            y: scene.joystickBase.position.y
        ))

        #expect(abs(scene.joystickVector.x - 1) < 0.001)
        #expect(abs(scene.joystickVector.y) < 0.001)
        #expect(abs(scene.joystickKnob.position.x - scene.joystickRadius) < 0.001)
        #expect(abs(scene.joystickKnob.position.y) < 0.001)
    }

    private func makeScene(size: CGSize = CGSize(width: 1_024, height: 768)) -> GameScene {
        let session = GameSessionState(localPlayer: PlayerState(
            id: "local",
            name: "Player",
            worldPosition: GameMapLayout.playerSpawnPosition,
            isConnected: true
        ))
        let scene = GameScene(
            size: size,
            sessionState: session,
            tacticalMapViewModel: TacticalMapViewModel(sessionState: session)
        )
        scene.addChild(scene.cameraNode)
        scene.camera = scene.cameraNode
        return scene
    }
}
