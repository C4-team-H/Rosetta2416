import SpriteKit

extension GameScene {
    func createShipMap() {
        shipMapNode?.removeFromParent()
        let map = ShipMapNode(debugEnabled: Self.isShipMapDebugEnabled)
        map.zPosition = 0
        addChild(map)
        shipMapNode = map
    }

    func createPlayer() {
        player?.removeFromParent()
        player = SKShapeNode(circleOfRadius: playerRadius)
        player.name = "player"
        player.fillColor = SKColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1)
        player.strokeColor = .white
        player.lineWidth = 2
        player.position = sessionState.localPlayer.worldPosition
        player.zPosition = 0

        let body = SKPhysicsBody(circleOfRadius: playerRadius)
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.restitution = 0
        body.friction = 0
        body.linearDamping = 0
        body.angularDamping = 0
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.door
        body.contactTestBitMask = PhysicsCategory.roomTrigger | PhysicsCategory.interactable | PhysicsCategory.door
        player.physicsBody = body

        (shipMapNode?.playerLayer ?? self).addChild(player)
    }

    func createJoystick() {
        joystickBase = SKShapeNode(circleOfRadius: joystickRadius)
        joystickBase.position = CGPoint(x: -size.width / 2 + joystickRadius + 50, y: -size.height / 2 + joystickRadius + 70)
        joystickBase.fillColor = .black.withAlphaComponent(0.2)
        joystickBase.strokeColor = .white.withAlphaComponent(0.6)
        joystickBase.lineWidth = 3
        joystickBase.zPosition = 10
        cameraNode.addChild(joystickBase)

        joystickKnob = SKShapeNode(circleOfRadius: 25)
        joystickKnob.fillColor = .white.withAlphaComponent(0.8)
        joystickKnob.strokeColor = .clear
        joystickKnob.zPosition = 11
        joystickBase.addChild(joystickKnob)
    }

    func createInteractiveStations() {
        stationNodes.values.forEach { $0.removeFromParent() }
        stationNodes.removeAll()
        let parent = shipMapNode?.furnitureLayer ?? self
        for definition in GameMapLayout.stationDefinitions {
            let station = makeStationNode(id: definition.id, at: definition.worldPosition)
            attachInteractionSensor(to: station, id: definition.id)
            parent.addChild(station)
            stationNodes[definition.id] = station
        }
    }

    func createFoodObject() {
        foodObject?.removeFromParent()
        foodObject = makeStationNode(id: "kitchen-food", at: GameMapLayout.foodStationPosition)
        foodObject.fillColor = SKColor(red: 0.9, green: 0.5, blue: 0.15, alpha: 1)
        attachInteractionSensor(to: foodObject, id: "kitchen-food")
        (shipMapNode?.furnitureLayer ?? self).addChild(foodObject)
    }

    func refreshStoryVisuals() {
        let objectiveByID = Dictionary(uniqueKeysWithValues: sessionState.objectives.map { ($0.id, $0) })
        for (id, node) in stationNodes {
            guard let objective = objectiveByID[id] else { continue }
            switch objective.status {
            case .completed:
                node.fillColor = SKColor(red: 0.15, green: 0.68, blue: 0.38, alpha: 1)
                node.alpha = 0.85
            case .available, .active:
                node.fillColor = SKColor(red: 0.82, green: 0.55, blue: 0.28, alpha: 1)
                node.alpha = 1
            case .blocked:
                node.fillColor = .red
                node.alpha = 0.9
            case .locked:
                node.fillColor = .darkGray
                node.alpha = 0.45
            }
        }
        shipMapNode?.synchronizeDoors(with: sessionState.storySystem)
        lightingSystem.apply(sessionState.sharedStory.powerState, to: self)
    }

    func animateCompletedStation(id: String) {
        guard let node = stationNodes[id] else { return }
        node.run(.sequence([
            .group([.scale(to: 1.35, duration: 0.18), .fadeAlpha(to: 1, duration: 0.18)]),
            .scale(to: 1, duration: 0.32)
        ]))
    }

    func enableCandleLight() {
        candleLight?.removeFromParent()
        let light = CandleLightNode(
            sceneSize: size,
            configuration: .init(radius: 180, darknessOpacity: 0.94, lightIntensity: 1, softness: 0.42, verticalScale: 1.08, warmth: 0.08, flickerAmount: 0.025, flickerSpeed: 1)
        )
        light.zPosition = 9.5
        light.position = CGPoint(x: -size.width / 2, y: -size.height / 2)
        light.update(lightPosition: CGPoint(x: size.width / 2, y: size.height / 2))
        cameraNode.addChild(light)
        candleLight = light
    }

    func positionActionButtons() {
        let position = CGPoint(x: size.width / 2 - 90, y: -size.height / 2 + joystickRadius + 70)
        actionButton?.position = position
        foodActionButton?.position = position
    }

    private func makeStationNode(id: String, at position: CGPoint) -> SKShapeNode {
        let station = SKShapeNode(rectOf: CGSize(width: 50, height: 40), cornerRadius: 8)
        station.name = id
        station.position = position
        station.fillColor = SKColor(red: 0.82, green: 0.55, blue: 0.28, alpha: 1)
        station.strokeColor = .white
        station.lineWidth = 2
        station.zPosition = 2

        let screen = SKShapeNode(rectOf: CGSize(width: 36, height: 28), cornerRadius: 4)
        screen.fillColor = .white
        screen.strokeColor = .clear
        screen.zPosition = 3
        station.addChild(screen)

        let glyph = SKShapeNode(rectOf: CGSize(width: 22, height: 4), cornerRadius: 1)
        glyph.fillColor = .black
        glyph.strokeColor = .clear
        glyph.zRotation = .pi / 4
        glyph.zPosition = 4
        screen.addChild(glyph)

        let glow = SKShapeNode(circleOfRadius: 45)
        glow.name = "glow"
        glow.strokeColor = .cyan.withAlphaComponent(0.38)
        glow.lineWidth = 2
        glow.zPosition = 1
        glow.run(.repeatForever(.sequence([.scale(to: 1.2, duration: 1.2), .scale(to: 0.85, duration: 1.2)])))
        station.addChild(glow)
        return station
    }

    private func attachInteractionSensor(to node: SKNode, id: String) {
        node.userData = NSMutableDictionary(dictionary: ["interactableID": id])
        let body = SKPhysicsBody(circleOfRadius: 76)
        body.isDynamic = false
        body.affectedByGravity = false
        body.categoryBitMask = PhysicsCategory.interactable
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.player
        node.physicsBody = body
    }
}
