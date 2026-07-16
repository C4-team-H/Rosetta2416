import SpriteKit

final class ShipDoorNode: SKShapeNode {
    let doorID: DoorID
    private(set) var state: DoorState = .closed
    var stateDidChange: ((DoorID, DoorState) -> Void)?

    var isOpen: Bool { state == .open }
    var isLocked: Bool { state == .locked }

    init(definition: DoorDefinition) {
        doorID = definition.id
        super.init()

        name = definition.id.nodeName
        position = definition.worldPosition
        path = localClosedPath(for: definition.shape, around: position)
        fillColor = .red.withAlphaComponent(0.78)
        strokeColor = .white
        lineWidth = GameMapLayout.scaled(2)

        let body = filledPhysicsBody(for: definition.shape, around: position)
        body.isDynamic = false
        body.affectedByGravity = false
        body.restitution = 0
        physicsBody = body
        applyState()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @discardableResult
    func open() -> Bool {
        guard state != .locked else { return false }
        transition(to: .open)
        return true
    }

    func close() {
        if state == .locked {
            applyState()
        } else {
            transition(to: .closed)
        }
    }

    func lock() {
        transition(to: .locked)
    }

    func unlock() {
        if state == .locked {
            transition(to: .closed)
        }
    }

    func applyRuntimeState(_ state: DoorState) {
        transition(to: state)
    }

    private func transition(to newState: DoorState) {
        guard state != newState else {
            applyState()
            return
        }
        state = newState
        applyState()
        stateDidChange?(doorID, state)
    }

    private func applyState() {
        switch state {
        case .open:
            physicsBody?.categoryBitMask = PhysicsCategory.none
            physicsBody?.collisionBitMask = PhysicsCategory.none
            physicsBody?.contactTestBitMask = PhysicsCategory.none
            fillColor = .cyan.withAlphaComponent(0.08)
            strokeColor = .cyan.withAlphaComponent(0.28)
            alpha = 0.35

        case .closed, .locked:
            physicsBody?.categoryBitMask = PhysicsCategory.closedDoor
            physicsBody?.collisionBitMask = PhysicsCategory.player
            physicsBody?.contactTestBitMask = PhysicsCategory.player
            fillColor = state == .locked
                ? .red.withAlphaComponent(0.78)
                : .orange.withAlphaComponent(0.72)
            strokeColor = .white
            alpha = 1
        }
    }
}

final class ShipMapNode: SKNode {
    private(set) var map: GameMap
    let floorLayer = SKNode()
    let roomTriggerLayer = SKNode()
    let collisionLayer = SKNode()
    let furnitureLayer = SKNode()
    let doorLayer = SKNode()
    let playerLayer = SKNode()
    let foregroundLayer = SKNode()
    let debugLayer = SKNode()

    private(set) var doorNodes: [DoorID: ShipDoorNode] = [:]
    private(set) var geometryNodes: [MapElementID: SKNode] = [:]
    private var debugDoorwayNodes: [DoorID: SKShapeNode] = [:]
    let isDebugEnabled: Bool
    private let doorStateDidChange: (DoorID, DoorState) -> Void

    var doorStates: [DoorID: DoorState] {
        doorNodes.mapValues(\.state)
    }

    init(
        map: GameMap = GameMapLayout.ship,
        debugEnabled: Bool,
        doorStateDidChange: @escaping (DoorID, DoorState) -> Void = { _, _ in }
    ) {
        self.map = map
        isDebugEnabled = debugEnabled
        self.doorStateDidChange = doorStateDidChange
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
        for definition in map.doorways {
            guard let door = doorNodes[definition.id] else { continue }
            if story.canAccess(definition.roomID) {
                door.unlock()
                _ = door.open()
            } else {
                door.lock()
            }
        }
    }

    /// Rebuilds all geometry-owned layers without recreating the scene, player,
    /// floor texture, camera, HUD, or story state. Door state is preserved by ID.
    func apply(
        map newMap: GameMap,
        changeSet: MapGeometryChangeSet = .fullReplacement
    ) {
        let previousDoorStates = doorStates
        let previousWorldSize = map.configuration.worldSize
        map = newMap

        if changeSet.isFullReplacement {
            floorLayer.removeAllChildren()
            roomTriggerLayer.removeAllChildren()
            collisionLayer.removeAllChildren()
            doorLayer.removeAllChildren()
            geometryNodes.removeAll(keepingCapacity: true)
            doorNodes.removeAll(keepingCapacity: true)
            buildFloor()
            buildRoomTriggers()
            buildBlockingColliders()
            buildDoors()
        } else {
            let categories = changeSet.categories
            if previousWorldSize != newMap.configuration.worldSize {
                floorLayer.removeAllChildren()
                buildFloor()
            }
            if categories.contains(.room) {
                roomTriggerLayer.removeAllChildren()
                removeRegisteredNodes(in: [.room])
                buildRoomTriggers()
            }
            if !categories.isDisjoint(with: [.wall, .blockedArea, .object]) {
                collisionLayer.removeAllChildren()
                removeRegisteredNodes(in: [.wall, .blockedArea, .object])
                buildBlockingColliders()
            }
            if categories.contains(.doorway) {
                doorLayer.removeAllChildren()
                removeRegisteredNodes(in: [.doorway])
                doorNodes.removeAll(keepingCapacity: true)
                buildDoors()
            }
        }
        if changeSet.isFullReplacement || changeSet.categories.contains(.doorway) {
            for (doorID, state) in previousDoorStates {
                doorNodes[doorID]?.applyRuntimeState(state)
            }
        }
        if isDebugEnabled {
            debugLayer.removeAllChildren()
            debugDoorwayNodes.removeAll(keepingCapacity: true)
            buildDebugOverlay()
        }
    }

    func node(for elementID: MapElementID) -> SKNode? {
        geometryNodes[elementID]
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
        background.size = map.configuration.worldSize
        background.zPosition = 0
        floorLayer.addChild(background)
    }

    private func buildRoomTriggers() {
        for definition in map.roomTriggers {
            let node = SKNode()
            node.name = definition.roomID.triggerNodeName
            node.position = CGPoint(x: definition.worldFrame.midX, y: definition.worldFrame.midY)
            node.userData = NSMutableDictionary(dictionary: [
                "roomID": definition.roomID.rawValue,
                "triggerID": definition.roomID.triggerNodeName
            ])

            let body = filledPhysicsBody(for: definition.shape, around: node.position)
            body.isDynamic = false
            body.affectedByGravity = false
            body.categoryBitMask = PhysicsCategory.roomTrigger
            body.collisionBitMask = PhysicsCategory.none
            body.contactTestBitMask = PhysicsCategory.player
            node.physicsBody = body
            roomTriggerLayer.addChild(node)
            geometryNodes[MapElementID(category: .room, rawValue: definition.sourceID)] = node
        }
    }

    private func buildBlockingColliders() {
        let hasExplicitWallColliders = map.colliders.contains { $0.kind == .interiorWall }
        if !hasExplicitWallColliders {
            for wall in map.wallSegments {
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
        }

        for definition in map.colliders {
            guard let node = makeColliderNode(definition) else { continue }
            collisionLayer.addChild(node)
            let category: MapElementCategory = switch definition.kind {
            case .hull: .blockedArea
            case .interiorWall: .wall
            case .furniture, .machinery: .object
            }
            geometryNodes[MapElementID(category: category, rawValue: definition.id)] = node
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
            node.position = CGPoint(x: definition.shape.bounds.midX, y: definition.shape.bounds.midY)
            let body = filledPhysicsBody(for: .polygon(points), around: node.position)
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
        for definition in map.doorways {
            let door = ShipDoorNode(definition: definition)
            door.stateDidChange = { [weak self] doorID, state in
                self?.handleDoorStateChange(doorID: doorID, state: state)
            }
            doorLayer.addChild(door)
            doorNodes[definition.id] = door
            geometryNodes[MapElementID(category: .doorway, rawValue: definition.sourceID)] = door
            doorStateDidChange(definition.id, door.state)
        }
    }

    private func removeRegisteredNodes(in categories: Set<MapElementCategory>) {
        let ids = geometryNodes.keys.filter { categories.contains($0.category) }
        for id in ids {
            geometryNodes.removeValue(forKey: id)
        }
    }

    private func buildDebugOverlay() {
        for wall in map.wallSegments {
            let path = CGMutablePath()
            path.move(to: wall.start)
            path.addLine(to: wall.end)
            let node = SKShapeNode(path: path)
            node.strokeColor = .red.withAlphaComponent(0.82)
            node.lineWidth = GameMapLayout.wallThickness
            debugLayer.addChild(node)
        }

        for definition in map.colliders {
            let color: SKColor = definition.kind == .hull ? .red : .systemRed
            if let node = debugNode(for: definition.shape, color: color) {
                node.name = "debug-\(definition.id)"
                debugLayer.addChild(node)
            }
        }

        for room in map.rooms {
            let node = debugNode(for: room.walkableShape, color: .green) ?? SKShapeNode()
            node.fillColor = .green.withAlphaComponent(0.10)
            node.strokeColor = .green
            node.lineWidth = GameMapLayout.scaled(2)
            node.isUserInteractionEnabled = false
            debugLayer.addChild(node)

            addDebugLabel(
                room.roomID.displayName,
                at: CGPoint(x: room.walkableFrame.midX, y: room.walkableFrame.midY),
                color: .green
            )
        }

        for corridor in map.corridors {
            let node = debugNode(for: corridor.shape, color: .cyan) ?? SKShapeNode()
            node.fillColor = .cyan.withAlphaComponent(0.10)
            node.strokeColor = .cyan
            node.lineWidth = GameMapLayout.scaled(2)
            node.isUserInteractionEnabled = false
            debugLayer.addChild(node)
        }

        for definition in map.doorways {
            let node = debugNode(for: definition.shape, color: .magenta) ?? SKShapeNode()
            node.fillColor = .clear
            node.strokeColor = .magenta
            node.lineWidth = GameMapLayout.scaled(3)
            node.isUserInteractionEnabled = false
            debugLayer.addChild(node)
            debugDoorwayNodes[definition.id] = node
            updateDoorwayDebugNode(node, state: doorNodes[definition.id]?.state ?? .closed)

            addDebugLabel(
                definition.id.displayName,
                at: CGPoint(
                    x: definition.worldPosition.x,
                    y: definition.worldPosition.y + GameMapLayout.scaled(14)
                ),
                color: .magenta
            )
        }

        for spawn in map.spawnPoints {
            let marker = SKShapeNode(circleOfRadius: GameMapLayout.scaled(9))
            marker.position = spawn.worldPosition
            marker.fillColor = .green.withAlphaComponent(0.45)
            marker.strokeColor = .green
            marker.lineWidth = GameMapLayout.scaled(2)

            let label = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
            label.text = spawn.roomID.displayName
            label.fontSize = GameMapLayout.scaled(11)
            label.fontColor = .green
            label.position = CGPoint(x: 0, y: GameMapLayout.scaled(14))
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
        node.lineWidth = GameMapLayout.scaled(2)
        node.isUserInteractionEnabled = false
        return node
    }

    private func handleDoorStateChange(doorID: DoorID, state: DoorState) {
        if let debugNode = debugDoorwayNodes[doorID] {
            updateDoorwayDebugNode(debugNode, state: state)
        }
        doorStateDidChange(doorID, state)
    }

    private func updateDoorwayDebugNode(_ node: SKShapeNode, state: DoorState) {
        switch state {
        case .open:
            node.fillColor = .yellow.withAlphaComponent(0.16)
            node.strokeColor = .yellow
        case .closed, .locked:
            node.fillColor = .magenta.withAlphaComponent(0.16)
            node.strokeColor = .magenta
        }
    }

    private func addDebugLabel(_ text: String, at position: CGPoint, color: SKColor) {
        let label = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        label.text = text
        label.fontSize = GameMapLayout.scaled(9)
        label.fontColor = color
        label.position = position
        label.zPosition = 2
        label.isUserInteractionEnabled = false
        debugLayer.addChild(label)
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

private func localClosedPath(
    for shape: ShipColliderShape,
    around origin: CGPoint
) -> CGPath {
    let path = CGMutablePath()
    switch shape {
    case let .rectangle(rect):
        path.addRect(rect.offsetBy(dx: -origin.x, dy: -origin.y))
    case let .polygon(points), let .edgeLoop(points):
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: first.x - origin.x, y: first.y - origin.y))
        points.dropFirst().forEach {
            path.addLine(to: CGPoint(x: $0.x - origin.x, y: $0.y - origin.y))
        }
        path.closeSubpath()
    }
    return path
}

/// SpriteKit polygon bodies must be convex. A freeform editor polygon is split
/// into triangle bodies so concave room/object/door outlines remain usable.
private func filledPhysicsBody(
    for shape: ShipColliderShape,
    around origin: CGPoint
) -> SKPhysicsBody {
    switch shape {
    case let .rectangle(rect):
        return SKPhysicsBody(rectangleOf: rect.size)
    case let .polygon(points), let .edgeLoop(points):
        let triangles = triangulatedPolygon(points)
        guard !triangles.isEmpty else {
            return SKPhysicsBody(rectangleOf: shape.bounds.size)
        }
        let bodies = triangles.map { triangle -> SKPhysicsBody in
            let path = CGMutablePath()
            path.move(to: CGPoint(x: triangle[0].x - origin.x, y: triangle[0].y - origin.y))
            triangle.dropFirst().forEach {
                path.addLine(to: CGPoint(x: $0.x - origin.x, y: $0.y - origin.y))
            }
            path.closeSubpath()
            return SKPhysicsBody(polygonFrom: path)
        }
        return bodies.count == 1 ? bodies[0] : SKPhysicsBody(bodies: bodies)
    }
}

private func triangulatedPolygon(_ points: [CGPoint]) -> [[CGPoint]] {
    guard points.count >= 3 else { return [] }
    var indices = Array(points.indices)
    if polygonSignedArea(points) < 0 { indices.reverse() }
    var triangles: [[CGPoint]] = []
    var attempts = 0

    while indices.count > 3, attempts < points.count * points.count {
        var clippedEar = false
        for offset in indices.indices {
            let previous = indices[(offset - 1 + indices.count) % indices.count]
            let current = indices[offset]
            let next = indices[(offset + 1) % indices.count]
            let a = points[previous]
            let b = points[current]
            let c = points[next]
            guard crossProduct(a, b, c) > 0.000_1 else { continue }
            guard !indices.contains(where: { candidate in
                candidate != previous && candidate != current && candidate != next
                    && pointInsideTriangle(points[candidate], a, b, c)
            }) else { continue }
            triangles.append([a, b, c])
            indices.remove(at: offset)
            clippedEar = true
            break
        }
        guard clippedEar else { return [] }
        attempts += 1
    }
    if indices.count == 3 {
        triangles.append(indices.map { points[$0] })
    }
    return triangles
}

private func polygonSignedArea(_ points: [CGPoint]) -> CGFloat {
    guard points.count >= 3 else { return 0 }
    return points.indices.reduce(CGFloat.zero) { area, index in
        let next = points[(index + 1) % points.count]
        return area + points[index].x * next.y - next.x * points[index].y
    } / 2
}

private func crossProduct(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
    (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
}

private func pointInsideTriangle(
    _ point: CGPoint,
    _ a: CGPoint,
    _ b: CGPoint,
    _ c: CGPoint
) -> Bool {
    let ab = crossProduct(a, b, point)
    let bc = crossProduct(b, c, point)
    let ca = crossProduct(c, a, point)
    let hasNegative = ab < -0.000_1 || bc < -0.000_1 || ca < -0.000_1
    let hasPositive = ab > 0.000_1 || bc > 0.000_1 || ca > 0.000_1
    return !(hasNegative && hasPositive)
}
