import SpriteKit

extension GameScene {
    func createRegularGrid() {
        gridContainer?.removeFromParent()
        let container = SKNode()
        gridContainer = container
        addChild(container)

        let tileSize: CGFloat = 60
        let columns = Int(ceil(GameMapLayout.worldSize.width / tileSize))
        let rows = Int(ceil(GameMapLayout.worldSize.height / tileSize))
        for row in 0..<rows {
            for column in 0..<columns {
                let tile = SKShapeNode(rectOf: CGSize(width: tileSize, height: tileSize))
                tile.position = CGPoint(x: CGFloat(column) * tileSize + tileSize / 2, y: CGFloat(row) * tileSize + tileSize / 2)
                tile.fillColor = (row + column).isMultiple(of: 2)
                    ? SKColor(red: 0.18, green: 0.22, blue: 0.3, alpha: 1)
                    : SKColor(red: 0.15, green: 0.18, blue: 0.25, alpha: 1)
                tile.strokeColor = SKColor(red: 0.25, green: 0.3, blue: 0.4, alpha: 1)
                tile.lineWidth = 1
                tile.zPosition = -1
                container.addChild(tile)
            }
        }
    }

    func createPlayer() {
        player = SKShapeNode(circleOfRadius: playerRadius)
        player.fillColor = SKColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1)
        player.strokeColor = .white
        player.lineWidth = 2
        player.position = sessionState.localPlayer.worldPosition
        player.zPosition = 4
        addChild(player)
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
        for definition in GameMapLayout.stationDefinitions {
            let station = makeStationNode(id: definition.id, at: definition.worldPosition)
            addChild(station)
            stationNodes[definition.id] = station
        }
    }

    func createFoodObject() {
        foodObject?.removeFromParent()
        foodObject = makeStationNode(id: "kitchen-food", at: GameMapLayout.foodStationPosition)
        foodObject.fillColor = SKColor(red: 0.9, green: 0.5, blue: 0.15, alpha: 1)
        addChild(foodObject)
    }

    func createAlbumBook() {
        albumBookNode?.removeFromParent()
        // Bottom-left corner of Sleeping Room at CGRect(x:200, y:825, w:350, h:350)
        let bookPos = CGPoint(x: 230, y: 850)
        let book = SKShapeNode(rectOf: CGSize(width: 24, height: 30), cornerRadius: 3)
        book.name = "album-book"
        book.position = bookPos
        book.fillColor = SKColor(red: 0.25, green: 0.45, blue: 0.75, alpha: 1)
        book.strokeColor = SKColor(red: 0.8, green: 0.85, blue: 1.0, alpha: 0.9)
        book.lineWidth = 1.5
        book.zPosition = 2

        // Book spine line
        let spine = SKShapeNode(rectOf: CGSize(width: 3, height: 28))
        spine.fillColor = SKColor(red: 0.15, green: 0.30, blue: 0.60, alpha: 1)
        spine.strokeColor = .clear
        spine.position = CGPoint(x: -9, y: 0)
        spine.zPosition = 1
        book.addChild(spine)

        // Pages lines
        for i in 0..<3 {
            let line = SKShapeNode(rectOf: CGSize(width: 10, height: 1.5))
            line.fillColor = .white.withAlphaComponent(0.5)
            line.strokeColor = .clear
            line.position = CGPoint(x: 4, y: CGFloat(i * 5) - 4)
            book.addChild(line)
        }

        addChild(book)
        albumBookNode = book
    }

    func createObstacles() {
        obstacles.forEach { $0.node.removeFromParent() }
        obstacles.removeAll()
        doorNodes.removeAll()
        children.filter { $0.name == "roomLabel" }.forEach { $0.removeFromParent() }

        for wall in GameMapLayout.wallSegments { addWall(from: wall.start, to: wall.end) }
        for room in GameMapLayout.rooms {
            let label = SKLabelNode(fontNamed: GameFont.fontName)
            label.text = room.name
            label.fontSize = 20
            label.fontColor = .white.withAlphaComponent(0.15)
            label.position = CGPoint(x: room.worldFrame.midX, y: room.worldFrame.midY)
            label.zPosition = 0
            label.name = "roomLabel"
            addChild(label)
        }
        updateDoorGates()
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
        updateDoorGates()
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

    private func addWall(from start: CGPoint, to end: CGPoint) {
        let thickness: CGFloat = 16
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        guard length > 0 else { return }
        let size = abs(dx) > abs(dy)
            ? CGSize(width: length, height: thickness)
            : CGSize(width: thickness, height: length)
        let position = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let wall = SKShapeNode(rectOf: size, cornerRadius: 4)
        wall.position = position
        wall.fillColor = SKColor(red: 0.28, green: 0.30, blue: 0.38, alpha: 1)
        wall.strokeColor = SKColor(red: 0.40, green: 0.45, blue: 0.55, alpha: 1)
        wall.lineWidth = 1.5
        wall.zPosition = 2
        addChild(wall)
        obstacles.append(Obstacle(node: wall, size: size, absPos: position))
    }

    private func updateDoorGates() {
        for definition in GameMapLayout.doorDefinitions {
            let allowed = sessionState.storySystem.canAccess(definition.roomID)
            if allowed {
                if let node = doorNodes.removeValue(forKey: definition.id) {
                    obstacles.removeAll { $0.node === node }
                    node.run(.sequence([.fadeOut(withDuration: 0.25), .removeFromParent()]))
                }
                continue
            }

            guard doorNodes[definition.id] == nil else { continue }
            let door = SKShapeNode(rectOf: definition.size, cornerRadius: 5)
            door.name = definition.id
            door.position = definition.worldPosition
            door.fillColor = .red.withAlphaComponent(0.72)
            door.strokeColor = .white
            door.lineWidth = 2
            door.zPosition = 3
            addChild(door)
            doorNodes[definition.id] = door
            obstacles.append(Obstacle(node: door, size: definition.size, absPos: definition.worldPosition))
        }
    }
}
