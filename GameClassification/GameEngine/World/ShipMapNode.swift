import SpriteKit

final class ShipDoorNode: SKShapeNode {
    let doorID: DoorID
    private(set) var isOpen = false
    private(set) var isLocked = false

    init(definition: DoorDefinition) {
        doorID = definition.id
        super.init()

        name = definition.id.nodeName
        path = CGPath(
            roundedRect: CGRect(
                x: -definition.size.width / 2,
                y: -definition.size.height / 2,
                width: definition.size.width,
                height: definition.size.height
            ),
            cornerWidth: 4,
            cornerHeight: 4,
            transform: nil
        )
        position = definition.worldPosition
        fillColor = .red.withAlphaComponent(0.78)
        strokeColor = .white
        lineWidth = 2

        let body = SKPhysicsBody(rectangleOf: definition.size)
        body.isDynamic = false
        body.affectedByGravity = false
        body.restitution = 0
        physicsBody = body
        close()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @discardableResult
    func open() -> Bool {
        guard !isLocked else { return false }
        isOpen = true
        physicsBody?.categoryBitMask = PhysicsCategory.none
        physicsBody?.collisionBitMask = PhysicsCategory.none
        physicsBody?.contactTestBitMask = PhysicsCategory.none
        fillColor = .cyan.withAlphaComponent(0.08)
        strokeColor = .cyan.withAlphaComponent(0.28)
        alpha = 0.35
        return true
    }

    func close() {
        isOpen = false
        physicsBody?.categoryBitMask = PhysicsCategory.door
        physicsBody?.collisionBitMask = PhysicsCategory.player
        physicsBody?.contactTestBitMask = PhysicsCategory.player
        fillColor = isLocked ? .red.withAlphaComponent(0.78) : .orange.withAlphaComponent(0.72)
        strokeColor = .white
        alpha = 1
    }

    func lock() {
        isLocked = true
        close()
    }

    func unlock() {
        isLocked = false
        if !isOpen {
            fillColor = .orange.withAlphaComponent(0.72)
        }
    }
}

final class ShipMapNode: SKNode {
    let floorLayer = SKNode()
    let roomTriggerLayer = SKNode()
    let collisionLayer = SKNode()
    let furnitureLayer = SKNode()
    let doorLayer = SKNode()
    let playerLayer = SKNode()
    let foregroundLayer = SKNode()
    let debugLayer = SKNode()

    private(set) var doorNodes: [DoorID: ShipDoorNode] = [:]
    let isDebugEnabled: Bool

    init(debugEnabled: Bool) {
        isDebugEnabled = debugEnabled
        super.init()
        name = "ShipMapRoot"
        configureLayers()
        buildFloor()
        buildRoomTriggers()
        buildBlockingColliders()
        buildDoors()
        if debugEnabled { buildDebugOverlay() }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func synchronizeDoors(with story: StoryProgressionSystem) {
        for definition in GameMapLayout.doorDefinitions {
            guard let door = doorNodes[definition.id] else { continue }
            if story.canAccess(definition.roomID) {
                door.unlock()
                _ = door.open()
            } else {
                door.lock()
            }
        }
    }

    private func configureLayers() {
        let layers: [(SKNode, String, CGFloat)] = [
            (floorLayer, "FloorLayer", 0),
            (roomTriggerLayer, "RoomTriggerLayer", 1),
            (collisionLayer, "CollisionLayer", 2),
            (furnitureLayer, "FurnitureLayer", 10),
            (doorLayer, "DoorLayer", 20),
            (playerLayer, "PlayerLayer", 30),
            (foregroundLayer, "ForegroundLayer", 40),
            (debugLayer, "DebugLayer", 90)
        ]
        for (layer, name, zPosition) in layers {
            layer.name = name
            layer.zPosition = zPosition
            addChild(layer)
        }
    }

    private func buildFloor() {
        let background = SKSpriteNode(imageNamed: "ShipMap")
        background.name = "ShipMapBackground"
        background.anchorPoint = CGPoint(x: 0, y: 0)
        background.position = .zero
        background.size = GameMapLayout.worldSize
        background.zPosition = 0
        floorLayer.addChild(background)
    }

    private func buildRoomTriggers() {
        for definition in GameMapLayout.roomTriggerDefinitions {
            let node = SKNode()
            node.name = definition.roomID.triggerNodeName
            node.position = CGPoint(x: definition.worldFrame.midX, y: definition.worldFrame.midY)
            node.userData = NSMutableDictionary(dictionary: [
                "roomID": definition.roomID.rawValue,
                "triggerID": definition.roomID.triggerNodeName
            ])

            let body = SKPhysicsBody(rectangleOf: definition.worldFrame.size)
            body.isDynamic = false
            body.affectedByGravity = false
            body.categoryBitMask = PhysicsCategory.roomTrigger
            body.collisionBitMask = PhysicsCategory.none
            body.contactTestBitMask = PhysicsCategory.player
            node.physicsBody = body
            roomTriggerLayer.addChild(node)
        }
    }

    private func buildBlockingColliders() {
        for wall in GameMapLayout.wallSegments {
            let dx = wall.end.x - wall.start.x
            let dy = wall.end.y - wall.start.y
            let length = hypot(dx, dy)
            guard length > 0 else { continue }

            let node = SKNode()
            node.name = "wall-\(wall.id)"
            node.position = CGPoint(x: (wall.start.x + wall.end.x) / 2, y: (wall.start.y + wall.end.y) / 2)
            node.zRotation = atan2(dy, dx)
            node.physicsBody = staticBlockingBody(
                rectangleOf: CGSize(width: length, height: GameMapLayout.wallThickness)
            )
            collisionLayer.addChild(node)
        }

        for definition in GameMapLayout.colliderDefinitions {
            guard let node = makeColliderNode(definition) else { continue }
            collisionLayer.addChild(node)
        }
    }

    private func makeColliderNode(_ definition: ShipColliderDefinition) -> SKNode? {
        let node = SKNode()
        node.name = definition.id

        switch definition.shape {
        case let .rectangle(rect):
            node.position = CGPoint(x: rect.midX, y: rect.midY)
            node.physicsBody = staticBlockingBody(rectangleOf: rect.size)

        case let .polygon(points):
            guard points.count >= 3 else { return nil }
            let origin = definition.shape.bounds.origin
            let path = CGMutablePath()
            path.move(to: CGPoint(x: points[0].x - origin.x, y: points[0].y - origin.y))
            for point in points.dropFirst() {
                path.addLine(to: CGPoint(x: point.x - origin.x, y: point.y - origin.y))
            }
            path.closeSubpath()
            node.position = origin
            let body = SKPhysicsBody(polygonFrom: path)
            configureStaticBlockingBody(body)
            node.physicsBody = body

        case let .edgeLoop(points):
            guard points.count >= 3 else { return nil }
            let path = CGMutablePath()
            path.move(to: points[0])
            points.dropFirst().forEach { path.addLine(to: $0) }
            path.closeSubpath()
            let body = SKPhysicsBody(edgeLoopFrom: path)
            configureStaticBlockingBody(body)
            node.physicsBody = body
        }
        return node
    }

    private func buildDoors() {
        for definition in GameMapLayout.doorDefinitions {
            let door = ShipDoorNode(definition: definition)
            doorLayer.addChild(door)
            doorNodes[definition.id] = door
        }
    }

    private func buildDebugOverlay() {
        for wall in GameMapLayout.wallSegments {
            let path = CGMutablePath()
            path.move(to: wall.start)
            path.addLine(to: wall.end)
            let node = SKShapeNode(path: path)
            node.strokeColor = .red.withAlphaComponent(0.82)
            node.lineWidth = GameMapLayout.wallThickness
            debugLayer.addChild(node)
        }

        for definition in GameMapLayout.colliderDefinitions {
            let color: SKColor = definition.kind == .hull ? .red : .systemRed
            if let node = debugNode(for: definition.shape, color: color) {
                node.name = "debug-\(definition.id)"
                debugLayer.addChild(node)
            }
        }

        for trigger in GameMapLayout.roomTriggerDefinitions {
            let node = SKShapeNode(rect: trigger.worldFrame)
            node.fillColor = .cyan.withAlphaComponent(0.12)
            node.strokeColor = .cyan
            node.lineWidth = 2
            debugLayer.addChild(node)
        }

        for definition in GameMapLayout.doorDefinitions {
            let rect = CGRect(
                x: definition.worldPosition.x - definition.size.width / 2,
                y: definition.worldPosition.y - definition.size.height / 2,
                width: definition.size.width,
                height: definition.size.height
            )
            let node = SKShapeNode(rect: rect)
            node.fillColor = .magenta.withAlphaComponent(0.14)
            node.strokeColor = .magenta
            node.lineWidth = 3
            debugLayer.addChild(node)
        }

        for spawn in GameMapLayout.spawnPoints {
            let marker = SKShapeNode(circleOfRadius: 9)
            marker.position = spawn.worldPosition
            marker.fillColor = .green.withAlphaComponent(0.45)
            marker.strokeColor = .green
            marker.lineWidth = 2

            let label = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
            label.text = spawn.roomID.displayName
            label.fontSize = 11
            label.fontColor = .green
            label.position = CGPoint(x: 0, y: 14)
            marker.addChild(label)
            debugLayer.addChild(marker)
        }
    }

    private func debugNode(for shape: ShipColliderShape, color: SKColor) -> SKShapeNode? {
        let path = CGMutablePath()
        switch shape {
        case let .rectangle(rect):
            path.addRect(rect)
        case let .polygon(points), let .edgeLoop(points):
            guard let first = points.first else { return nil }
            path.move(to: first)
            points.dropFirst().forEach { path.addLine(to: $0) }
            path.closeSubpath()
        }
        let node = SKShapeNode(path: path)
        node.fillColor = color.withAlphaComponent(0.10)
        node.strokeColor = color
        node.lineWidth = 2
        return node
    }

    private func staticBlockingBody(rectangleOf size: CGSize) -> SKPhysicsBody {
        let body = SKPhysicsBody(rectangleOf: size)
        configureStaticBlockingBody(body)
        return body
    }

    private func configureStaticBlockingBody(_ body: SKPhysicsBody) {
        body.isDynamic = false
        body.affectedByGravity = false
        body.restitution = 0
        body.friction = 0
        body.categoryBitMask = PhysicsCategory.wall
        body.collisionBitMask = PhysicsCategory.player
        body.contactTestBitMask = PhysicsCategory.none
    }
}
