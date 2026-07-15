import SpriteKit

extension GameScene {
    func checkProximityToInteractiveObject() {
        guard let player else { return }
        let nearest = stationNodes
            .map { (id: $0.key, node: $0.value, distance: hypot(player.position.x - $0.value.position.x, player.position.y - $0.value.position.y)) }
            .filter { $0.distance <= 76 }
            .min { $0.distance < $1.distance }

        guard let nearest,
              let objective = sessionState.objectives.first(where: { $0.id == nearest.id }) else {
            activeStationID = nil
            lastDeniedStationID = nil
            hideInteractionButton()
            return
        }

        switch objective.status {
        case .available, .active:
            activeStationID = nearest.id
            lastDeniedStationID = nil
            showInteractionButton(title: "REPAIR")
        case .locked, .blocked:
            activeStationID = nil
            hideInteractionButton()
            if lastDeniedStationID != nearest.id {
                lastDeniedStationID = nearest.id
                applyStoryEffects(sessionState.handle(.stationInteractionRequested(nearest.id)))
            }
        case .completed:
            activeStationID = nil
            hideInteractionButton()
        }
    }

    func checkProximityToFoodObject() {
        guard let player, let foodObject else { return }
        let distance = hypot(player.position.x - foodObject.position.x, player.position.y - foodObject.position.y)
        distance <= 80 ? showFoodInteractionButton() : hideFoodInteractionButton()
    }

    func checkProximityToLockedDoor() {
        guard let player else { return }
        let nearest = GameMapLayout.doorDefinitions
            .filter { !sessionState.storySystem.canAccess($0.roomID) }
            .map { definition in
                (
                    definition: definition,
                    distance: hypot(
                        player.position.x - definition.worldPosition.x,
                        player.position.y - definition.worldPosition.y
                    )
                )
            }
            .filter { $0.distance <= 88 }
            .min { $0.distance < $1.distance }

        guard let nearest else {
            lastDeniedDoorID = nil
            return
        }
        guard lastDeniedDoorID != nearest.definition.id else { return }
        lastDeniedDoorID = nearest.definition.id
        applyStoryEffects(sessionState.handle(.roomEntered(nearest.definition.roomID)))
    }

    func requestActiveStationInteraction() {
        guard let activeStationID else { return }
        eventDelegate?.gameScene(self, didRequestObjective: activeStationID)
    }

    func requestFoodInteraction() {
        eventDelegate?.gameSceneDidRequestFoodChallenge(self)
    }

    func restartGame() {
        sessionState.retryCheckpoint()
        restorePlayerFromSession()
        resetJoystick()
        pencilTouch = nil
        pencilTarget = nil
        hideTargetMarker()
        isPaused = false
    }

    private func showInteractionButton(title: String) {
        hideFoodInteractionButton()
        if actionButton != nil { return }
        actionButton = makeActionButton(name: "drawButton", title: title, color: SKColor(red: 0.9, green: 0.5, blue: 0.15, alpha: 1))
        if let actionButton { cameraNode.addChild(actionButton) }
    }

    func hideInteractionButton() {
        actionButton?.removeFromParent()
        actionButton = nil
    }

    private func showFoodInteractionButton() {
        hideInteractionButton()
        if foodActionButton != nil { return }
        foodActionButton = makeActionButton(name: "foodDrawButton", title: "EAT", color: SKColor(red: 0.15, green: 0.68, blue: 0.38, alpha: 1))
        if let foodActionButton { cameraNode.addChild(foodActionButton) }
    }

    func hideFoodInteractionButton() {
        foodActionButton?.removeFromParent()
        foodActionButton = nil
    }

    private func makeActionButton(name: String, title: String, color: SKColor) -> SKShapeNode {
        let button = SKShapeNode(circleOfRadius: 40)
        button.fillColor = color
        button.strokeColor = .white
        button.lineWidth = 2
        button.position = CGPoint(x: size.width / 2 - 90, y: -size.height / 2 + joystickRadius + 70)
        button.zPosition = 12
        button.name = name

        let label = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        label.text = title
        label.fontSize = 13
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.name = name
        button.addChild(label)
        button.run(.repeatForever(.sequence([.scale(to: 1.12, duration: 0.6), .scale(to: 0.96, duration: 0.6)])))
        return button
    }
}
