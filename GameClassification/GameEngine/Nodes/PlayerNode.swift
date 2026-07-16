import SpriteKit

final class PlayerNode: SKShapeNode {
    let collisionFootprint: CollisionFootprint

    init(configuration: GameMapConfiguration, debugEnabled: Bool) {
        collisionFootprint = configuration.playerFootprint
        super.init()

        let visualRadius = configuration.playerVisualRadius
        path = CGPath(
            ellipseIn: CGRect(
                x: -visualRadius,
                y: -visualRadius,
                width: visualRadius * 2,
                height: visualRadius * 2
            ),
            transform: nil
        )
        name = "player"
        fillColor = SKColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1)
        strokeColor = .white
        lineWidth = GameMapLayout.scaled(2)

        let body = SKPhysicsBody(
            circleOfRadius: collisionFootprint.radius,
            center: collisionFootprint.centerOffset
        )
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.restitution = 0
        body.friction = 0
        body.linearDamping = 0
        body.angularDamping = 0
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.closedDoor
        body.contactTestBitMask = PhysicsCategory.roomTrigger
            | PhysicsCategory.interaction
            | PhysicsCategory.closedDoor
        physicsBody = body

        if debugEnabled { addFootprintDebugOverlay(configuration: configuration) }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func addFootprintDebugOverlay(configuration: GameMapConfiguration) {
        let footprintNode = SKShapeNode(circleOfRadius: collisionFootprint.radius)
        footprintNode.name = "DebugPlayerFootprint"
        footprintNode.position = collisionFootprint.centerOffset
        footprintNode.fillColor = .green.withAlphaComponent(0.08)
        footprintNode.strokeColor = .green
        footprintNode.lineWidth = GameMapLayout.scaled(1.5)
        footprintNode.zPosition = 100
        footprintNode.isUserInteractionEnabled = false
        addChild(footprintNode)

        for (index, offset) in collisionFootprint.validationOffsets.enumerated() {
            let sample = SKShapeNode(circleOfRadius: GameMapLayout.scaled(1.8))
            sample.name = "DebugFootprintSample-\(index)"
            sample.position = offset
            sample.fillColor = .green
            sample.strokeColor = .clear
            sample.zPosition = 101
            sample.isUserInteractionEnabled = false
            addChild(sample)
        }
    }
}
