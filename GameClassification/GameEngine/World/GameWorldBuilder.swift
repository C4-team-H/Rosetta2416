import SpriteKit

extension GameScene {
    func createShipMap() {
        shipMapNode?.removeFromParent()
        let map = worldLoader.makeShipMapNode(
            map: gameMap,
            debugEnabled: debugSettings.isMapDebugEnabled
        ) { [weak self] doorID, state in
            self?.walkabilitySystem.updateDoorState(state, for: doorID)
        }
        map.zPosition = 0
        addChild(map)
        shipMapNode = map
        walkabilitySystem.updateDoorStates(map.doorStates)
    }

    func createPlayer() {
        player?.removeInteractionSensor()
        player?.removeFromParent()
        let playerNode = worldLoader.makePlayerNode(
            configuration: gameMap.configuration,
            debugEnabled: debugSettings.isMapDebugEnabled
        )
        player = playerNode
        player.position = validatedPlayerPosition(sessionState.localPlayer.worldPosition)
        player.zPosition = 0
        lastValidPlayerPosition = player.position
        lastMovementResult = .stationary(at: player.position)
        let parent = shipMapNode?.playerLayer ?? self
        parent.addChild(player)
        player.attachInteractionSensor(to: parent)
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
        for definition in gameMap.stations {
            let station = makeStationNode(id: definition.id, at: definition.worldPosition)
            attachInteractionSensor(to: station, id: definition.id)
            parent.addChild(station)
            stationNodes[definition.id] = station
        }
    }

    func createFoodObject() {
        foodObject?.removeFromParent()
        foodObject = makeStationNode(id: "kitchen-food", at: gameMap.foodStationPosition)
        foodObject.fillColor = SKColor(red: 0.9, green: 0.5, blue: 0.15, alpha: 1)
        addChild(foodObject)
    }

    func createAlbumBook() {
        albumBookNode?.removeFromParent()
        let book = AlbumBookNode()
        book.position = geometryStore.configuration.albumBookPosition
        book.zPosition = 2

        (shipMapNode?.furnitureLayer ?? self).addChild(book)
        albumBookNode = book
    }

    func refreshStoryVisuals() {
        let objectiveByID = Dictionary(uniqueKeysWithValues: sessionState.objectives.map { ($0.id, $0) })
        let visibility = stationVisibilitySystem
        for (id, node) in stationNodes {
            if let objective = objectiveByID[id] {
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
            node.isHidden = !visibility.shouldShowStation(interactionID: id)
        }
        foodObject?.isHidden = !visibility.shouldShowStation(interactionID: StationVisibilitySystem.kitchenInteractionID)
        albumBookNode?.isHidden = !visibility.shouldShowStation(interactionID: StationVisibilitySystem.albumInteractionID)
        if albumBookNode?.isHidden == true {
            albumBookNode?.setProximityHighlighted(false, animated: false)
            hideAlbumButton()
        }
        shipMapNode?.synchronizeDoors(with: sessionState.storySystem)
        if let doorStates = shipMapNode?.doorStates {
            walkabilitySystem.updateDoorStates(doorStates)
        }
        lightingSystem.apply(sessionState.sharedStory.powerState, to: self)
    }

    func updateStationVisibility() {
        let visibility = stationVisibilitySystem
        for (id, node) in stationNodes {
            node.isHidden = !visibility.shouldShowStation(interactionID: id)
        }
        foodObject?.isHidden = !visibility.shouldShowStation(interactionID: StationVisibilitySystem.kitchenInteractionID)
        albumBookNode?.isHidden = !visibility.shouldShowStation(interactionID: StationVisibilitySystem.albumInteractionID)
        if albumBookNode?.isHidden == true {
            albumBookNode?.setProximityHighlighted(false, animated: false)
            hideAlbumButton()
        }
    }

    func animateCompletedStation(id: String) {
        guard let node = stationNodes[id] else { return }
        guard let completionVisual = node.copy() as? SKShapeNode, let parent = node.parent else { return }
        completionVisual.name = "completion-visual-\(id)"
        completionVisual.isHidden = false
        completionVisual.physicsBody = nil
        completionVisual.userData = nil
        completionVisual.zPosition = node.zPosition + 1
        parent.addChild(completionVisual)
        completionVisual.run(.sequence([
            .group([.scale(to: 1.35, duration: 0.18), .fadeAlpha(to: 1, duration: 0.18)]),
            .group([.scale(to: 1, duration: 0.32), .fadeOut(withDuration: 0.32)]),
            .removeFromParent()
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
        let station = SKShapeNode(
            rectOf: GameMapLayout.scaled(CGSize(width: 50, height: 40)),
            cornerRadius: GameMapLayout.scaled(8)
        )
        station.name = id
        station.position = position
        station.fillColor = SKColor(red: 0.82, green: 0.55, blue: 0.28, alpha: 1)
        station.strokeColor = .white
        station.lineWidth = GameMapLayout.scaled(2)
        station.zPosition = 2

        let screen = SKShapeNode(
            rectOf: GameMapLayout.scaled(CGSize(width: 36, height: 28)),
            cornerRadius: GameMapLayout.scaled(4)
        )
        screen.fillColor = .white
        screen.strokeColor = .clear
        screen.zPosition = 3
        station.addChild(screen)

        let glyph = SKShapeNode(
            rectOf: GameMapLayout.scaled(CGSize(width: 22, height: 4)),
            cornerRadius: GameMapLayout.scaled(1)
        )
        glyph.fillColor = .black
        glyph.strokeColor = .clear
        glyph.zRotation = .pi / 4
        glyph.zPosition = 4
        screen.addChild(glyph)

        let glow = SKShapeNode(circleOfRadius: GameMapLayout.scaled(45))
        glow.name = "glow"
        glow.strokeColor = .cyan.withAlphaComponent(0.38)
        glow.lineWidth = GameMapLayout.scaled(2)
        glow.zPosition = 1
        glow.run(.repeatForever(.sequence([.scale(to: 1.2, duration: 1.2), .scale(to: 0.85, duration: 1.2)])))
        station.addChild(glow)
        return station
    }

    private func attachInteractionSensor(to node: SKNode, id: String) {
        node.userData = NSMutableDictionary(dictionary: ["interactableID": id])
        let body = SKPhysicsBody(circleOfRadius: GameMapLayout.scaled(76))
        body.isDynamic = false
        body.affectedByGravity = false
        body.categoryBitMask = PhysicsCategory.interaction
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.playerSensor
        node.physicsBody = body
    }
}
