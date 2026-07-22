import SpriteKit
import Testing
@testable import Rosetta

@Suite("Player animation controller")
@MainActor
struct PlayerAnimationControllerTests {
    @Test("Horizontal input controls facing and vertical input preserves it")
    func facingDirection() {
        let sprite = SKSpriteNode()
        let controller = PlayerAnimationController(sprite: sprite)

        controller.update(movementVector: CGPoint(x: -1, y: 0), isJoystickActive: true)
        #expect(controller.facingDirection == .left)
        #expect(sprite.xScale < 0)
        #expect(controller.isWalking)

        controller.update(movementVector: CGPoint(x: 0, y: 1), isJoystickActive: true)
        #expect(controller.facingDirection == .left)
        #expect(sprite.xScale < 0)

        controller.update(movementVector: CGPoint(x: 0.5, y: 0.5), isJoystickActive: true)
        #expect(controller.facingDirection == .right)
        #expect(sprite.xScale > 0)
    }

    @Test("Idle stops the walk action and restores Astro-1")
    func idleState() {
        let sprite = SKSpriteNode()
        let controller = PlayerAnimationController(sprite: sprite)
        let idleTexture = sprite.texture

        controller.update(movementVector: CGPoint(x: 1, y: 0), isJoystickActive: true)
        #expect(controller.isWalking)

        sprite.texture = SKTexture(imageNamed: "Astro-8")
        controller.update(movementVector: .zero, isJoystickActive: false)

        #expect(!controller.isWalking)
        #expect(sprite.action(forKey: "player.walk") == nil)
        #expect(sprite.texture === idleTexture)
    }

}
