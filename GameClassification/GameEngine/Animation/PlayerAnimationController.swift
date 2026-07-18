import SpriteKit

/// Owns the player's visual animation state independently from scene movement speed.
final class PlayerAnimationController {
    enum FacingDirection: Equatable {
        case left
        case right
    }

    struct Configuration {
        let idleFrameName: String
        let walkFrameNames: [String]
        let timePerFrame: TimeInterval

        static let astroWalk = Configuration(
            idleFrameName: "Astro-1",
            walkFrameNames: (1...8).map { "Astro-\($0)" },
            timePerFrame: 0.09
        )
    }

    private enum Constants {
        static let walkActionKey = "player.walk"
        static let movementEpsilon: CGFloat = 0.001
    }

    private weak var sprite: SKSpriteNode?
    private let idleTexture: SKTexture
    private let walkAction: SKAction

    private(set) var facingDirection: FacingDirection
    private(set) var isWalking = false

    init(
        sprite: SKSpriteNode,
        configuration: Configuration = .astroWalk,
        initialFacingDirection: FacingDirection = .right
    ) {
        precondition(!configuration.walkFrameNames.isEmpty, "Walk animation requires at least one frame")
        precondition(configuration.timePerFrame > 0, "Walk animation frame duration must be positive")

        self.sprite = sprite
        facingDirection = initialFacingDirection

        idleTexture = Self.makeTexture(named: configuration.idleFrameName)
        let walkTextures = configuration.walkFrameNames.map(Self.makeTexture(named:))
        walkAction = .repeatForever(
            .animate(
                with: walkTextures,
                timePerFrame: configuration.timePerFrame,
                resize: false,
                restore: false
            )
        )

        sprite.texture = idleTexture
        applyFacingDirection()
    }

    /// Updates facing from horizontal input and animation state from joystick activity.
    /// Purely vertical input intentionally preserves the previous horizontal direction.
    func update(movementVector: CGPoint, isJoystickActive: Bool) {
        if movementVector.x > Constants.movementEpsilon {
            facingDirection = .right
        } else if movementVector.x < -Constants.movementEpsilon {
            facingDirection = .left
        }
        applyFacingDirection()

        let hasMovementInput = hypot(movementVector.x, movementVector.y) > Constants.movementEpsilon
        if isJoystickActive && hasMovementInput {
            startWalkingIfNeeded()
        } else {
            stopWalking()
        }
    }

    func stopWalking() {
        guard let sprite else { return }
        if isWalking || sprite.action(forKey: Constants.walkActionKey) != nil {
            sprite.removeAction(forKey: Constants.walkActionKey)
        }
        sprite.texture = idleTexture
        isWalking = false
    }

    private func startWalkingIfNeeded() {
        guard let sprite, sprite.action(forKey: Constants.walkActionKey) == nil else { return }
        sprite.run(walkAction, withKey: Constants.walkActionKey)
        isWalking = true
    }

    private func applyFacingDirection() {
        guard let sprite else { return }
        sprite.xScale = facingDirection == .right ? 1 : -1
    }

    private static func makeTexture(named name: String) -> SKTexture {
        let texture = SKTexture(imageNamed: name)
        texture.filteringMode = .linear
        return texture
    }
}
