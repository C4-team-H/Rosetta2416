import SpriteKit

/// The node's dynamic body is only the small floor contact beneath the character.
/// The artwork keeps its configured size and the interaction sensor is independent.
final class PlayerNode: SKShapeNode {
    let collisionFootprint: CollisionFootprint
    let characterSprite: SKSpriteNode
    let characterFootprintBounds: CGRect
    let footprintBounds: CGRect
    let footprintCornerRadius: CGFloat
    let navigationFootprint: CollisionFootprint
    let interactionSensor: SKNode
    let animationController: PlayerAnimationController

    init(configuration: GameMapConfiguration, debugEnabled: Bool) {
        collisionFootprint = configuration.playerFootprint

        let sprite = SKSpriteNode(texture: SKTexture(imageNamed: "Astro-1"))
        let characterBounds = Self.makeCharacterBounds(
            visualRadius: configuration.playerVisualRadius,
            textureSize: sprite.texture?.size()
        )
        let footBounds = Self.makeFootprintBounds(
            footprint: configuration.playerFootprint
        )
        let cornerRadius = footBounds.height / 2
        let footprintPath = Self.makeRoundedFootprintPath(
            bounds: footBounds,
            cornerRadius: cornerRadius
        )

        characterSprite = sprite
        characterFootprintBounds = characterBounds
        footprintBounds = footBounds
        footprintCornerRadius = cornerRadius
        navigationFootprint = CollisionFootprint(
            centerOffset: collisionFootprint.centerOffset,
            size: collisionFootprint.size,
            obstacleRadius: collisionFootprint.obstacleRadius
        )
        interactionSensor = Self.makeInteractionSensor(footprintBounds: footBounds)
        animationController = PlayerAnimationController(sprite: sprite)
        super.init()

        name = "playerFootprint"
        path = footprintPath
        fillColor = debugEnabled ? .green.withAlphaComponent(0.08) : .clear
        strokeColor = debugEnabled ? .green : .clear
        lineWidth = debugEnabled ? GameMapLayout.scaled(1.5) : 0

        sprite.name = "playerCharacter"
        sprite.size = characterBounds.size
        sprite.anchorPoint = CGPoint(
            x: 0.5,
            y: -characterBounds.minY / characterBounds.height
        )
        sprite.zPosition = 1
        addChild(sprite)

        let body = SKPhysicsBody(polygonFrom: footprintPath)
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.friction = 0
        body.restitution = 0
        body.linearDamping = 0
        body.angularDamping = 0
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.closedDoor
        body.contactTestBitMask = PhysicsCategory.none
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func attachInteractionSensor(to parent: SKNode) {
        interactionSensor.removeFromParent()
        parent.addChild(interactionSensor)
        synchronizeInteractionSensor()
    }

    func removeInteractionSensor() {
        interactionSensor.removeFromParent()
    }

    func setMovementVelocity(direction: CGPoint, speed: CGFloat) {
        setMovementVelocity(Self.velocity(direction: direction, speed: speed))
    }

    func setMovementVelocity(_ velocity: CGVector) {
        physicsBody?.velocity = velocity
        physicsBody?.angularVelocity = 0
        interactionSensor.physicsBody?.velocity = .zero
        interactionSensor.physicsBody?.angularVelocity = 0
    }

    func stopMovement() {
        physicsBody?.velocity = .zero
        physicsBody?.angularVelocity = 0
        interactionSensor.physicsBody?.velocity = .zero
        interactionSensor.physicsBody?.angularVelocity = 0
    }

    func synchronizeInteractionSensor() {
        guard interactionSensor.parent === parent else { return }
        interactionSensor.position = CGPoint(
            x: position.x + footprintBounds.midX,
            y: position.y + footprintBounds.midY
        )
        interactionSensor.physicsBody?.velocity = .zero
        interactionSensor.physicsBody?.angularVelocity = 0
    }

    func updateAnimation(movementVector: CGPoint, isMoving: Bool) {
        animationController.update(
            movementVector: movementVector,
            isJoystickActive: isMoving
        )
    }

    static func velocity(direction input: CGPoint, speed: CGFloat) -> CGVector {
        let magnitude = hypot(input.x, input.y)
        guard magnitude > 0.001, speed > 0 else { return .zero }
        let scale = speed / max(1, magnitude)
        return CGVector(dx: input.x * scale, dy: input.y * scale)
    }

    static func makeCharacterBounds(
        visualRadius: CGFloat,
        textureSize: CGSize? = SKTexture(imageNamed: "Astro-1").size()
    ) -> CGRect {
        let characterHeight = visualRadius * 3
        let textureAspectRatio = textureSize.map { $0.width / $0.height } ?? 1
        let characterSize = CGSize(
            width: characterHeight * textureAspectRatio,
            height: characterHeight
        )
        let anchorPoint = CGPoint(x: 0.5, y: visualRadius / characterHeight)
        return CGRect(
            x: -characterSize.width * anchorPoint.x,
            y: -characterSize.height * anchorPoint.y,
            width: characterSize.width,
            height: characterSize.height
        )
    }

    static func makeFootprintBounds(
        footprint: CollisionFootprint
    ) -> CGRect {
        footprint.localBounds
    }

    private static func makeRoundedFootprintPath(
        bounds: CGRect,
        cornerRadius: CGFloat
    ) -> CGPath {
        let radius = min(cornerRadius, bounds.width / 2, bounds.height / 2)
        let diagonal = radius * 0.292_893_218
        let points = [
            CGPoint(x: bounds.minX + radius, y: bounds.minY),
            CGPoint(x: bounds.maxX - radius, y: bounds.minY),
            CGPoint(x: bounds.maxX - diagonal, y: bounds.minY + diagonal),
            CGPoint(x: bounds.maxX, y: bounds.minY + radius),
            CGPoint(x: bounds.maxX, y: bounds.maxY - radius),
            CGPoint(x: bounds.maxX - diagonal, y: bounds.maxY - diagonal),
            CGPoint(x: bounds.maxX - radius, y: bounds.maxY),
            CGPoint(x: bounds.minX + radius, y: bounds.maxY),
            CGPoint(x: bounds.minX + diagonal, y: bounds.maxY - diagonal),
            CGPoint(x: bounds.minX, y: bounds.maxY - radius),
            CGPoint(x: bounds.minX, y: bounds.minY + radius),
            CGPoint(x: bounds.minX + diagonal, y: bounds.minY + diagonal)
        ]
        let path = CGMutablePath()
        path.addLines(between: points)
        path.closeSubpath()
        return path
    }

    private static func makeInteractionSensor(footprintBounds: CGRect) -> SKNode {
        let sensor = SKNode()
        sensor.name = "playerInteractionSensor"

        let body = SKPhysicsBody(circleOfRadius: footprintBounds.width * 0.55)
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.friction = 0
        body.restitution = 0
        body.linearDamping = 0
        body.angularDamping = 0
        body.categoryBitMask = PhysicsCategory.playerSensor
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.roomTrigger
            | PhysicsCategory.interaction
            | PhysicsCategory.closedDoor
        sensor.physicsBody = body
        return sensor
    }
}
