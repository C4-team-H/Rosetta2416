import SpriteKit

extension GameScene {
    func checkProximityToInteractiveObject() {
        guard sessionState.phase == .playing, let player else {
            activeStationID = nil
            labTableNode?.setProximityHighlighted(false)
            labMonitor2Node?.setProximityHighlighted(false)
            labMonitor1Node?.setProximityHighlighted(false)
            hideInteractionButton()
            return
        }

        let stationCandidates = stationNodes
            .filter { !$0.value.isHidden }
            .map { (
                id: $0.key,
                distance: hypot(player.position.x - $0.value.position.x, player.position.y - $0.value.position.y),
                radius: GameMapLayout.scaled(76)
            ) }
        let labTableCandidate = labTableNode.flatMap { node -> (id: String, distance: CGFloat, radius: CGFloat)? in
            guard !node.isHidden else { return nil }
            return (
                id: Self.labScannerRepairInteractionID,
                distance: hypot(player.position.x - node.position.x, player.position.y - node.position.y),
                radius: LabTableNode.interactionRadius
            )
        }
        let labMonitor2Candidate = labMonitor2Node.flatMap { node -> (id: String, distance: CGFloat, radius: CGFloat)? in
            guard !node.isHidden,
                  let objective = sessionState.objectives.first(where: { $0.id == "lab-terminal-repair" }),
                  objective.status == .available || objective.status == .active else { return nil }
            return (
                id: "lab-terminal-repair",
                distance: hypot(player.position.x - node.position.x, player.position.y - node.position.y),
                radius: LabMonitor2Node.interactionRadius
            )
        }
        let labMonitor1Candidate = labMonitor1Node.flatMap { node -> (id: String, distance: CGFloat, radius: CGFloat)? in
            guard !node.isHidden,
                  let objective = sessionState.objectives.first(where: { $0.id == "lab-memory-repair" }),
                  objective.status == .available || objective.status == .active else { return nil }
            return (
                id: "lab-memory-repair",
                distance: hypot(player.position.x - node.position.x, player.position.y - node.position.y),
                radius: LabMonitor1Node.interactionRadius
            )
        }
        let nearest = (stationCandidates + [labTableCandidate, labMonitor2Candidate, labMonitor1Candidate].compactMap { $0 })
            .filter { $0.distance <= $0.radius }
            .min { $0.distance < $1.distance }
        labTableNode?.setProximityHighlighted(
            labTableCandidate.map { $0.distance <= $0.radius } ?? false
        )
        labMonitor2Node?.setProximityHighlighted(
            labMonitor2Candidate.map { $0.distance <= $0.radius } ?? false
        )
        labMonitor1Node?.setProximityHighlighted(
            labMonitor1Candidate.map { $0.distance <= $0.radius } ?? false
        )

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
        guard sessionState.phase == .playing, let player, let foodObject, !foodObject.isHidden else {
            foodObject?.setProximityHighlighted(false)
            hideFoodInteractionButton()
            return
        }
        let distance = hypot(player.position.x - foodObject.position.x, player.position.y - foodObject.position.y)
        let isWithinFoodRadius = distance <= KitchenTableNode.interactionRadius
        foodObject.setProximityHighlighted(isWithinFoodRadius)
        if isWithinFoodRadius {
            showFoodInteractionButton()
        } else {
            hideFoodInteractionButton()
        }
    }

    func checkProximityToAlbumBook() {
        guard sessionState.phase == .playing,
              let player,
              let albumBookNode,
              !albumBookNode.isHidden else {
            albumBookNode?.setProximityHighlighted(false)
            hideAlbumButton()
            return
        }
        let distance = hypot(player.position.x - albumBookNode.position.x, player.position.y - albumBookNode.position.y)
        let isWithinAlbumRadius = distance <= AlbumBookNode.interactionRadius
        albumBookNode.setProximityHighlighted(isWithinAlbumRadius)
        if isWithinAlbumRadius {
            showAlbumButton()
        } else {
            hideAlbumButton()
        }
    }

    func requestAlbumInteraction() {
        eventDelegate?.gameSceneDidRequestAlbum(self)
    }

    func checkProximityToLabMonitor2() {
        guard sessionState.phase == .playing,
              let player,
              let labMonitor2Node,
              !labMonitor2Node.isHidden,
              let objective = sessionState.objectives.first(where: { $0.id == "lab-terminal-repair" }),
              objective.status == .available || objective.status == .active else {
            labMonitor2Node?.setProximityHighlighted(false)
            return
        }
        let distance = hypot(player.position.x - labMonitor2Node.position.x, player.position.y - labMonitor2Node.position.y)
        let isWithinRadius = distance <= LabMonitor2Node.interactionRadius
        labMonitor2Node.setProximityHighlighted(isWithinRadius)
    }

    private func showAlbumButton() {
        // Don't show if another action button is already shown
        guard albumBookButton == nil else { return }
        hideInteractionButton()
        hideFoodInteractionButton()
        let button = makeActionButton(name: "albumButton", title: "READ", color: SKColor(red: 0.25, green: 0.45, blue: 0.80, alpha: 1))
        albumBookButton = button
        cameraNode.addChild(button)
    }

    func hideAlbumButton() {
        albumBookButton?.removeFromParent()
        albumBookButton = nil
    }

    func checkProximityToLockedDoor() {
        guard let player else { return }
        let nearest = gameMap.doorways
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
            .filter { $0.distance <= GameMapLayout.scaled(88) }
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
        clearPencilTarget()
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

        let label = SKLabelNode(fontNamed: GameFont.fontName)
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
