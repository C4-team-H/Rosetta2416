import SpriteKit

final class ShipDoorNode: SKShapeNode {
    private enum LockedVisual {
        static let rootName = "lockedDoorVisualRoot"
        static let glowName = "lockedDoorGlow"
        static let panelName = "lockedDoorInnerPanel"
        static let lockName = "lockedDoorLockGlyph"
        static let activationActionKey = "lockedDoorPop"
        static let indicatorActionKey = "lockedDoorIndicatorBlink"
    }

    let doorID: DoorID
    private(set) var state: DoorState = .closed
    var stateDidChange: ((DoorID, DoorState) -> Void)?

    private let closedPath: CGPath
    private let localBounds: CGRect
    private let lockedVisualRoot = SKNode()
    private let lockedGlow = SKShapeNode()
    private let lockedStatusLights = SKNode()

    var isOpen: Bool { state == .open }
    var isLocked: Bool { state == .locked }

    init(definition: DoorDefinition) {
        doorID = definition.id
        closedPath = localClosedPath(for: definition.shape, around: definition.worldPosition)
        localBounds = definition.worldFrame.offsetBy(
            dx: -definition.worldPosition.x,
            dy: -definition.worldPosition.y
        )
        super.init()

        name = definition.id.nodeName
        position = definition.worldPosition
        path = closedPath
        fillColor = .red.withAlphaComponent(0.78)
        strokeColor = .white
        lineWidth = GameMapLayout.scaled(2)

        let body = filledPhysicsBody(for: definition.shape, around: position)
        body.isDynamic = false
        body.affectedByGravity = false
        body.restitution = 0
        physicsBody = body
        buildLockedVisuals()
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
            setLockedVisualsActive(false)

        case .closed:
            physicsBody?.categoryBitMask = PhysicsCategory.closedDoor
            physicsBody?.collisionBitMask = PhysicsCategory.player
            physicsBody?.contactTestBitMask = PhysicsCategory.playerSensor
            fillColor = .orange.withAlphaComponent(0.72)
            strokeColor = .white
            alpha = 1
            setLockedVisualsActive(false)

        case .locked:
            physicsBody?.categoryBitMask = PhysicsCategory.closedDoor
            physicsBody?.collisionBitMask = PhysicsCategory.player
            physicsBody?.contactTestBitMask = PhysicsCategory.playerSensor
            fillColor = SKColor(red: 0.78, green: 0.08, blue: 0.10, alpha: 1)
            strokeColor = SKColor(red: 0.035, green: 0.06, blue: 0.09, alpha: 1)
            alpha = 1
            setLockedVisualsActive(true)
        }
    }

    private func buildLockedVisuals() {
        let shortSide = max(1, min(localBounds.width, localBounds.height))
        let longSide = max(localBounds.width, localBounds.height)
        let isHorizontal = localBounds.width >= localBounds.height
        let ink = SKColor(red: 0.035, green: 0.06, blue: 0.09, alpha: 1)
        let panelRed = SKColor(red: 0.91, green: 0.12, blue: 0.13, alpha: 1)
        let warning = SKColor(red: 1, green: 0.77, blue: 0.08, alpha: 1)

        lockedVisualRoot.name = LockedVisual.rootName
        lockedVisualRoot.zPosition = 1
        lockedVisualRoot.isUserInteractionEnabled = false
        addChild(lockedVisualRoot)

        lockedGlow.name = LockedVisual.glowName
        lockedGlow.path = closedPath
        lockedGlow.fillColor = .clear
        lockedGlow.strokeColor = ink
        lockedGlow.lineWidth = max(3, shortSide * 0.16)
        lockedGlow.glowWidth = 0
        lockedGlow.position.y = -shortSide * 0.07
        lockedGlow.alpha = 0.72
        lockedGlow.zPosition = 0
        lockedVisualRoot.addChild(lockedGlow)

        let clippedDetails = SKCropNode()
        clippedDetails.name = "lockedDoorClippedDetails"
        clippedDetails.zPosition = 1
        let mask = SKShapeNode(path: closedPath)
        mask.fillColor = .white
        mask.strokeColor = .clear
        clippedDetails.maskNode = mask
        lockedVisualRoot.addChild(clippedDetails)

        let panelInset = shortSide * 0.13
        let panelBounds = localBounds.insetBy(dx: panelInset, dy: panelInset)
        let innerPanel = SKShapeNode(
            rect: panelBounds,
            cornerRadius: shortSide * 0.18
        )
        innerPanel.name = LockedVisual.panelName
        innerPanel.fillColor = panelRed
        innerPanel.strokeColor = ink
        innerPanel.lineWidth = max(2.5, shortSide * 0.10)
        innerPanel.zPosition = 1
        clippedDetails.addChild(innerPanel)

        addCartoonPanelShading(
            to: clippedDetails,
            bounds: panelBounds,
            shortSide: shortSide,
            ink: ink
        )

        addHazardStripes(
            to: clippedDetails,
            bounds: localBounds,
            isHorizontal: isHorizontal,
            shortSide: shortSide,
            warning: warning,
            ink: ink
        )

        let centerSeam = SKShapeNode()
        centerSeam.name = "lockedDoorCenterSeam"
        let seamPath = CGMutablePath()
        if isHorizontal {
            seamPath.move(to: CGPoint(x: 0, y: localBounds.minY + shortSide * 0.12))
            seamPath.addLine(to: CGPoint(x: 0, y: localBounds.maxY - shortSide * 0.12))
        } else {
            seamPath.move(to: CGPoint(x: localBounds.minX + shortSide * 0.12, y: 0))
            seamPath.addLine(to: CGPoint(x: localBounds.maxX - shortSide * 0.12, y: 0))
        }
        centerSeam.path = seamPath
        centerSeam.strokeColor = ink.withAlphaComponent(0.88)
        centerSeam.lineWidth = max(2, shortSide * 0.07)
        centerSeam.glowWidth = 0
        centerSeam.zPosition = 3
        clippedDetails.addChild(centerSeam)

        let lockBadge = makeLockBadge(size: shortSide * 0.76, ink: ink, warning: warning)
        lockBadge.name = LockedVisual.lockName
        lockBadge.zPosition = 5
        clippedDetails.addChild(lockBadge)

        lockedStatusLights.name = "lockedDoorStatusLights"
        lockedStatusLights.zPosition = 4
        let requestedIndicatorOffset = max(shortSide * 0.32, longSide / 2 - shortSide * 0.42)
        let maximumIndicatorOffset = max(0, longSide / 2 - shortSide * 0.16)
        let indicatorOffset = min(requestedIndicatorOffset, maximumIndicatorOffset)
        for direction in [-1.0, 1.0] {
            let light = SKShapeNode(circleOfRadius: max(1.5, shortSide * 0.075))
            light.name = direction < 0 ? "lockedDoorStatusLightLeft" : "lockedDoorStatusLightRight"
            light.position = isHorizontal
                ? CGPoint(x: indicatorOffset * direction, y: 0)
                : CGPoint(x: 0, y: indicatorOffset * direction)
            light.fillColor = SKColor(red: 0.61, green: 0.91, blue: 0.92, alpha: 1)
            light.strokeColor = ink
            light.lineWidth = max(1.5, shortSide * 0.055)
            light.glowWidth = 0
            lockedStatusLights.addChild(light)
        }
        clippedDetails.addChild(lockedStatusLights)
    }

    private func addCartoonPanelShading(
        to parent: SKNode,
        bounds: CGRect,
        shortSide: CGFloat,
        ink: SKColor
    ) {
        let horizontalInset = shortSide * 0.24

        let highlightPath = CGMutablePath()
        highlightPath.move(to: CGPoint(
            x: bounds.minX + horizontalInset,
            y: bounds.maxY - shortSide * 0.14
        ))
        highlightPath.addLine(to: CGPoint(
            x: bounds.maxX - horizontalInset,
            y: bounds.maxY - shortSide * 0.14
        ))
        let highlight = SKShapeNode(path: highlightPath)
        highlight.name = "lockedDoorPanelHighlight"
        highlight.strokeColor = .white.withAlphaComponent(0.34)
        highlight.lineWidth = max(1.5, shortSide * 0.065)
        highlight.lineCap = .round
        highlight.zPosition = 2
        parent.addChild(highlight)

        let shadowPath = CGMutablePath()
        shadowPath.move(to: CGPoint(
            x: bounds.minX + horizontalInset,
            y: bounds.minY + shortSide * 0.12
        ))
        shadowPath.addLine(to: CGPoint(
            x: bounds.maxX - horizontalInset,
            y: bounds.minY + shortSide * 0.12
        ))
        let shadow = SKShapeNode(path: shadowPath)
        shadow.name = "lockedDoorPanelShadow"
        shadow.strokeColor = ink.withAlphaComponent(0.52)
        shadow.lineWidth = max(2, shortSide * 0.08)
        shadow.lineCap = .round
        shadow.zPosition = 2
        parent.addChild(shadow)

        let rivetInset = shortSide * 0.22
        let rivetPositions = [
            CGPoint(x: bounds.minX + rivetInset, y: bounds.minY + rivetInset),
            CGPoint(x: bounds.maxX - rivetInset, y: bounds.minY + rivetInset),
            CGPoint(x: bounds.minX + rivetInset, y: bounds.maxY - rivetInset),
            CGPoint(x: bounds.maxX - rivetInset, y: bounds.maxY - rivetInset)
        ]
        for (index, position) in rivetPositions.enumerated() {
            let rivet = SKShapeNode(circleOfRadius: max(1.1, shortSide * 0.045))
            rivet.name = "lockedDoorRivet-\(index)"
            rivet.position = position
            rivet.fillColor = SKColor(red: 0.74, green: 0.80, blue: 0.81, alpha: 1)
            rivet.strokeColor = ink
            rivet.lineWidth = max(0.75, shortSide * 0.025)
            rivet.zPosition = 4
            parent.addChild(rivet)
        }
    }

    private func addHazardStripes(
        to parent: SKNode,
        bounds: CGRect,
        isHorizontal: Bool,
        shortSide: CGFloat,
        warning: SKColor,
        ink: SKColor
    ) {
        let stripeCount = 9
        let longMinimum = isHorizontal ? bounds.minX : bounds.minY
        let longMaximum = isHorizontal ? bounds.maxX : bounds.maxY
        let inset = shortSide * 0.22
        let usableLength = max(0, longMaximum - longMinimum - inset * 2)

        for index in 0..<stripeCount {
            let progress = CGFloat(index) / CGFloat(max(1, stripeCount - 1))
            let longPosition = longMinimum + inset + usableLength * progress
            let stripePath = CGMutablePath()
            if isHorizontal {
                stripePath.move(to: CGPoint(x: longPosition - shortSide * 0.14, y: bounds.minY))
                stripePath.addLine(to: CGPoint(x: longPosition + shortSide * 0.14, y: bounds.maxY))
            } else {
                stripePath.move(to: CGPoint(x: bounds.minX, y: longPosition - shortSide * 0.14))
                stripePath.addLine(to: CGPoint(x: bounds.maxX, y: longPosition + shortSide * 0.14))
            }

            let stripe = SKShapeNode(path: stripePath)
            stripe.name = "lockedDoorHazardStripe-\(index)"
            stripe.strokeColor = index.isMultiple(of: 2) ? warning : ink
            stripe.lineWidth = max(2.5, shortSide * 0.16)
            stripe.zPosition = 0
            parent.addChild(stripe)
        }
    }

    private func makeLockBadge(size: CGFloat, ink: SKColor, warning: SKColor) -> SKNode {
        let badge = SKNode()

        let badgeSize = CGSize(width: size * 1.02, height: size * 0.76)
        let backgroundShadow = SKShapeNode(
            rectOf: badgeSize,
            cornerRadius: size * 0.18
        )
        backgroundShadow.position.y = -size * 0.07
        backgroundShadow.fillColor = ink.withAlphaComponent(0.76)
        backgroundShadow.strokeColor = .clear
        badge.addChild(backgroundShadow)

        let background = SKShapeNode(
            rectOf: badgeSize,
            cornerRadius: size * 0.18
        )
        background.fillColor = SKColor(red: 0.72, green: 0.80, blue: 0.82, alpha: 1)
        background.strokeColor = ink
        background.lineWidth = max(1.5, size * 0.08)
        badge.addChild(background)

        let shacklePath = CGMutablePath()
        shacklePath.move(to: CGPoint(x: -size * 0.16, y: size * 0.03))
        shacklePath.addLine(to: CGPoint(x: -size * 0.16, y: size * 0.15))
        shacklePath.addCurve(
            to: CGPoint(x: size * 0.16, y: size * 0.15),
            control1: CGPoint(x: -size * 0.16, y: size * 0.34),
            control2: CGPoint(x: size * 0.16, y: size * 0.34)
        )
        shacklePath.addLine(to: CGPoint(x: size * 0.16, y: size * 0.03))
        let shackle = SKShapeNode(path: shacklePath)
        shackle.strokeColor = ink
        shackle.lineWidth = max(1.75, size * 0.12)
        shackle.lineCap = .round
        badge.addChild(shackle)

        let lockBody = SKShapeNode(
            rectOf: CGSize(width: size * 0.48, height: size * 0.36),
            cornerRadius: size * 0.08
        )
        lockBody.position.y = -size * 0.11
        lockBody.fillColor = warning
        lockBody.strokeColor = ink
        lockBody.lineWidth = max(1.25, size * 0.07)
        badge.addChild(lockBody)

        let keyhole = SKShapeNode(circleOfRadius: max(0.8, size * 0.055))
        keyhole.position.y = -size * 0.08
        keyhole.fillColor = ink
        keyhole.strokeColor = .clear
        badge.addChild(keyhole)

        for direction in [-1.0, 1.0] as [CGFloat] {
            let screw = SKShapeNode(circleOfRadius: max(0.8, size * 0.04))
            screw.position = CGPoint(x: direction * size * 0.37, y: 0)
            screw.fillColor = .white.withAlphaComponent(0.72)
            screw.strokeColor = ink
            screw.lineWidth = max(0.5, size * 0.025)
            badge.addChild(screw)
        }

        return badge
    }

    private func setLockedVisualsActive(_ isActive: Bool) {
        let wasHidden = lockedVisualRoot.isHidden
        lockedVisualRoot.isHidden = !isActive
        guard isActive else {
            lockedVisualRoot.removeAction(forKey: LockedVisual.activationActionKey)
            lockedStatusLights.removeAction(forKey: LockedVisual.indicatorActionKey)
            lockedVisualRoot.setScale(1)
            lockedStatusLights.alpha = 1
            lockedStatusLights.setScale(1)
            return
        }

        if wasHidden {
            lockedVisualRoot.setScale(0.86)
            let overshoot = SKAction.scale(to: 1.08, duration: 0.10)
            overshoot.timingMode = .easeOut
            let settle = SKAction.scale(to: 1, duration: 0.08)
            settle.timingMode = .easeInEaseOut
            lockedVisualRoot.run(
                .sequence([overshoot, settle]),
                withKey: LockedVisual.activationActionKey
            )
        }

        if lockedStatusLights.action(forKey: LockedVisual.indicatorActionKey) == nil {
            let blink = SKAction.sequence([
                .group([
                    .fadeAlpha(to: 0.30, duration: 0.12),
                    .scale(to: 0.72, duration: 0.12)
                ]),
                .group([
                    .fadeAlpha(to: 1, duration: 0.10),
                    .scale(to: 1, duration: 0.10)
                ]),
                .wait(forDuration: 0.88)
            ])
            lockedStatusLights.run(
                .repeatForever(blink),
                withKey: LockedVisual.indicatorActionKey
            )
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
            body.contactTestBitMask = PhysicsCategory.playerSensor
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
            if definition.kind == .hull || !polygonIsConvex(points) {
                let body = filledPhysicsBody(for: .polygon(points), around: node.position)
                configureStaticBlockingBody(body)
                node.physicsBody = body
            } else {
                let body = SKPhysicsBody(
                    polygonFrom: localClosedPath(for: .polygon(points), around: node.position)
                )
                configureStaticBlockingBody(body)
                node.physicsBody = body
            }

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

private func polygonIsConvex(_ points: [CGPoint]) -> Bool {
    guard points.count >= 3 else { return false }
    var expectedSign: CGFloat = 0
    for index in points.indices {
        let a = points[index]
        let b = points[(index + 1) % points.count]
        let c = points[(index + 2) % points.count]
        let cross = crossProduct(a, b, c)
        guard abs(cross) > 0.000_1 else { continue }
        let sign: CGFloat = cross > 0 ? 1 : -1
        if expectedSign == 0 {
            expectedSign = sign
        } else if sign != expectedSign {
            return false
        }
    }
    return expectedSign != 0
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
