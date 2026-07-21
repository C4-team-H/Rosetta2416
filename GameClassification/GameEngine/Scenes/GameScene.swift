import SpriteKit

@MainActor
protocol GameSceneEventDelegate: AnyObject {
    func gameScene(_ scene: GameScene, didEnter room: RoomID)
    func gameScene(_ scene: GameScene, didExit room: RoomID)
    func gameScene(_ scene: GameScene, didRequestObjective objectiveID: String)
    func gameSceneDidRequestFoodChallenge(_ scene: GameScene)
    func gameSceneDidReachGameOver(_ scene: GameScene)
    func gameSceneDidRequestAlbum(_ scene: GameScene)
}

final class GameScene: SKScene {
    /// Preserves the requested 2.25x visual magnification in the 5504-point world.
    static let gameplayCameraScale: CGFloat = (0.6 / 2.25) * GameMapLayout.artworkScale
    /// Keeps camera-space lighting above every gameplay world layer while HUD children remain above it.
    static let cameraOverlayRootZ: CGFloat = 100
    static let labMemoryRepairInteractionID = "lab-memory-repair"
    static let labScannerRepairInteractionID = "lab-scanner-repair"
    static let engineIgnitionCoilInteractionID = "engine-ignition-coil"
    static let enginePowerConnectorInteractionID = "engine-power-connector"
    static let engineReactorLinkInteractionID = "engine-reactor-link"

    static let replacedEngineStationIDs: Set<String> = [
        engineIgnitionCoilInteractionID,
        enginePowerConnectorInteractionID,
        engineReactorLinkInteractionID
    ]

    let sessionState: GameSessionState
    let tacticalMapViewModel: TacticalMapViewModel
    let geometryStore: MapGeometryStore
    let debugSettings: GameDebugSettings
    let mapCoordinateConverter: MapEditorCoordinateConverter
    let mapGeometryUpdateSystem: MapGeometryUpdateSystem
    private(set) var gameMap: GameMap
    let worldLoader: WorldLoader
    let walkabilitySystem: WalkabilitySystem
    let collisionSystem: CollisionSystem
    let movementSystem: MovementSystem
    weak var eventDelegate: GameSceneEventDelegate?

    let cameraNode = SKCameraNode()
    var shipMapNode: ShipMapNode?
    var player: PlayerNode!
    var joystickBase: SKShapeNode!
    var joystickKnob: SKShapeNode!
    var gridContainer: SKNode?
    var actionButton: SKSpriteNode?
    var foodActionButton: SKSpriteNode?
    var foodObject: KitchenTableNode!
    var stationNodes: [String: SKShapeNode] = [:]
    var albumBookNode: AlbumBookNode?
    var albumBookButton: SKSpriteNode?
    var labTableNode: LabTableNode?
    var labMonitor2Node: LabMonitor2Node?
    var labMonitor1Node: LabMonitor1Node?
    var engineMonitorNode: EngineMonitorNode?
    var rocketPowerOffSmokeNode: RocketPowerOffSmokeNode?
    var activeStationID: String?
    var lastDeniedStationID: String?
    var lastDeniedDoorID: DoorID?

    var stationVisibilitySystem: StationVisibilitySystem {
        StationVisibilitySystem(
            storySystem: sessionState.storySystem,
            isDebugEnabled: DebugAvailability.isMapEditorAvailable && debugSettings.isMapDebugEnabled
        )
    }

    var isJoystickActive = false
    var joystickVector = CGPoint.zero
    var joystickActiveTouch: UITouch?
    let joystickRadius: CGFloat = 60
    let playerSpeed: CGFloat = GameMapLayout.scaled(80)

    var pencilTouch: UITouch?
    var pencilTarget: CGPoint?
    var pencilSpeedMultiplier: CGFloat = 1
    var targetMarker: SKShapeNode?
    let arrivalThreshold: CGFloat = GameMapLayout.scaled(4)
    let playerRadius = GameMapLayout.playerRadius
    var pencilBlockedFrameCount = 0
    static let maximumBlockedPencilFrames = 12
    var lastMovementResult: MovementResult = .stationary(at: GameMapLayout.playerSpawnPosition)
    var lastValidPlayerPosition = GameMapLayout.playerSpawnPosition

    var candleLight: CandleLightNode?
    let lightingSystem = LightingSystem()

    var pendingSensorContacts: [PendingSensorContact] = []
    var roomContactTracker = RoomContactTracker()
    var interactableContactCounts: [String: Int] = [:]
    var doorContactCounts: [DoorID: Int] = [:]

    private var wasMapInputSuspended = false
    private var previousUpdateTime: TimeInterval?
    var frameDeltaTime: TimeInterval = 0
    var physicsFrameStartPosition: CGPoint?
    private var didNotifyGameOver = false
    private var wasMapDebugEnabled = false
    private var debugEntryPlayerPosition: CGPoint?

    static var isShipMapDebugEnabled: Bool {
        #if DEBUG
        DebugAvailability.isMapEditorAvailable && ProcessInfo.processInfo.arguments.contains("-ShipMapDebug")
        #else
        false
        #endif
    }

    init(
        size: CGSize,
        sessionState: GameSessionState,
        tacticalMapViewModel: TacticalMapViewModel,
        geometryStore: MapGeometryStore? = nil,
        debugSettings: GameDebugSettings? = nil,
        mapCoordinateConverter: MapEditorCoordinateConverter? = nil
    ) {
        let geometryStore = geometryStore ?? tacticalMapViewModel.geometryStore
        let debugSettings = debugSettings ?? GameDebugSettings()
        let coordinateConverter = mapCoordinateConverter ?? MapEditorCoordinateConverter()
        let gameMap = GameMapLayout.makeRuntimeMap(
            from: geometryStore.configuration,
            revision: geometryStore.revision
        )
        let walkabilitySystem = WalkabilitySystem(map: gameMap)
        let collisionSystem = CollisionSystem(walkabilitySystem: walkabilitySystem)

        self.sessionState = sessionState
        self.tacticalMapViewModel = tacticalMapViewModel
        self.geometryStore = geometryStore
        self.debugSettings = debugSettings
        self.mapCoordinateConverter = coordinateConverter
        mapGeometryUpdateSystem = MapGeometryUpdateSystem(store: geometryStore)
        self.gameMap = gameMap
        worldLoader = WorldLoader()
        self.walkabilitySystem = walkabilitySystem
        self.collisionSystem = collisionSystem
        movementSystem = MovementSystem(collisionSystem: collisionSystem)
        super.init(size: size)
        cameraNode.zPosition = Self.cameraOverlayRootZ
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        sessionState.beginGameplay()
        backgroundColor = SKColor(red: 0.12, green: 0.14, blue: 0.2, alpha: 1)
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        camera = cameraNode
        addChild(cameraNode)
        cameraNode.setScale(Self.gameplayCameraScale)

        createShipMap()
        createPlayer()
        createJoystick()
        createInteractiveStations()
        createFoodObject()
        createAlbumBook()
        createLabTable()
        createLabMonitor2()
        createLabMonitor1()
        createEngineMonitor()
        createRocketPowerOffSmoke()
        enableCandleLight()
        refreshStoryVisuals()

        player.position = validatedPlayerPosition(sessionState.localPlayer.worldPosition)
        lastValidPlayerPosition = player.position
        lastMovementResult = .stationary(at: player.position)
        cameraNode.position = CameraFollowMath.clampedTarget(
            playerPosition: player.position,
            viewportSize: size,
            cameraScale: cameraNode.xScale,
            worldSize: gameMap.configuration.worldSize
        )
        synchronizeCandleLightWithPlayer()
        mapCoordinateConverter.attach(view: view, scene: self, camera: cameraNode)
        view.showsPhysics = debugSettings.isMapDebugEnabled && debugSettings.showCollisionBodies
        updateMapDebugTransition()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        joystickBase?.position = CGPoint(x: -size.width / 2 + joystickRadius + 50, y: -size.height / 2 + joystickRadius + 70)
        positionActionButtons()
        candleLight?.position = CGPoint(x: -size.width / 2, y: -size.height / 2)
        candleLight?.resize(to: size)
        synchronizeCandleLightWithPlayer()
    }

    override func update(_ currentTime: TimeInterval) {
        let rawDelta = previousUpdateTime.map { currentTime - $0 } ?? 0
        previousUpdateTime = currentTime
        frameDeltaTime = min(max(rawDelta, 0), 0.25)
        defer {
            let velocity = player?.physicsBody?.velocity ?? .zero
            player?.updateAnimation(
                movementVector: CGPoint(x: velocity.dx, y: velocity.dy),
                isMoving: hypot(velocity.dx, velocity.dy) > GameMapLayout.scaled(0.01)
            )
        }
        physicsFrameStartPosition = player?.position
        player?.synchronizeInteractionSensor()

        applyPendingMapGeometry()
        updateMapDebugTransition()
        view?.showsPhysics = debugSettings.isMapDebugEnabled && debugSettings.showCollisionBodies

        guard sessionState.phase != .gameOver, sessionState.phase != .victory else {
            stopPlayerMovement()
            resetJoystick()
            clearPencilTarget()
            return
        }
        if case .cutscene = sessionState.phase {
            stopPlayerMovement()
            resetJoystick()
            clearPencilTarget()
            return
        }

        if debugSettings.isEditingGameplaySuspended {
            if !wasMapInputSuspended {
                clearPencilTarget()
                pencilTouch = nil
                resetJoystick()
                wasMapInputSuspended = true
            }
            stopPlayerMovement()
            hideInteractionButton()
            hideFoodInteractionButton()
            hideAlbumButton()
            albumBookNode?.setProximityHighlighted(false, animated: false)
            foodObject?.setProximityHighlighted(false, animated: false)
            labTableNode?.setProximityHighlighted(false, animated: false)
            labMonitor2Node?.setProximityHighlighted(false, animated: false)
            labMonitor1Node?.setProximityHighlighted(false, animated: false)
            engineMonitorNode?.setProximityHighlighted(false, animated: false)
        } else if tacticalMapViewModel.isMapPresented || sessionState.showLowEnergyAlert {
            if !wasMapInputSuspended {
                clearPencilTarget()
                pencilTouch = nil
                resetJoystick()
                wasMapInputSuspended = true
            }
            stopPlayerMovement()
        } else {
            wasMapInputSuspended = false
            if pencilTarget != nil {
                movePlayerTowardTarget()
            } else if isJoystickActive, joystickVector != .zero {
                movePlayer()
            } else {
                stopPlayerMovement()
            }
        }

        let isMoving = hypot(
            lastMovementResult.appliedDisplacement.dx,
            lastMovementResult.appliedDisplacement.dy
        ) > GameMapLayout.scaled(0.01)

        if tacticalMapViewModel.shouldRunLocalSimulation
            && !isPaused
            && !debugSettings.isMapDebugEnabled {
            sessionState.updateEnergy(deltaTime: frameDeltaTime, isMoving: isMoving)
            if sessionState.phase == .gameOver, !didNotifyGameOver {
                didNotifyGameOver = true
                stopPlayerMovement()
                eventDelegate?.gameSceneDidReachGameOver(self)
            }
            checkProximityToInteractiveObject()
            checkProximityToFoodObject()
            checkProximityToLockedDoor()
            checkProximityToAlbumBook()
            checkProximityToLabMonitor2()
        }

        player?.updateEnergyBar(value: sessionState.energy)
        updateStationVisibility()

        if debugSettings.isMapDebugEnabled {
            candleLight?.isHidden = true
        } else {
            candleLight?.updateFlicker(currentTime: currentTime)
            lightingSystem.apply(sessionState.sharedStory.powerState, to: self)
        }
    }

    override func didSimulatePhysics() {
        super.didSimulatePhysics()
        if debugSettings.isMapDebugEnabled {
            pendingSensorContacts.removeAll(keepingCapacity: true)
        } else {
            processPendingPhysicsContacts()
        }

        recordPhysicsMovement()

        if !debugSettings.isEditingGameplaySuspended {
            let target = CameraFollowMath.clampedTarget(
                playerPosition: player.position,
                viewportSize: size,
                cameraScale: cameraNode.xScale,
                worldSize: gameMap.configuration.worldSize
            )
            cameraNode.position = CameraFollowMath.interpolatedPosition(
                from: cameraNode.position,
                to: target,
                deltaTime: frameDeltaTime
            )
        }
        synchronizeCandleLightWithPlayer()
        if !debugSettings.isEditingGameplaySuspended {
            sessionState.updateLocalPlayer(position: player.position)
        }
        mapCoordinateConverter.refresh()
    }

    override func willMove(from view: SKView) {
        stopPlayerMovement()
        player?.animationController.stopWalking()
        physicsWorld.contactDelegate = nil
        tacticalMapViewModel.closeMap()
        mapCoordinateConverter.detach(scene: self)
        sessionState.endGameplay()
        super.willMove(from: view)
    }

    func applyStoryEffects(_ effects: [StoryEffect]) {
        guard !effects.isEmpty, !debugSettings.isMapDebugEnabled else { return }
        refreshStoryVisuals()
        for effect in effects {
            switch effect {
            case let .powerChanged(power):
                lightingSystem.transition(to: power, in: self)
            case let .objectiveCompleted(id):
                animateCompletedStation(id: id)
            case .doorAccessChanged, .stationVisualChanged:
                refreshStoryVisuals()
            case let .cutscene(cutscene):
                stopPlayerMovement()
                resetJoystick()
                clearPencilTarget()
                if cutscene == .advancedToolsAcquired {
                    lightingSystem.playAdvancedToolsAcquired(in: self)
                }
                run(.sequence([
                    .wait(forDuration: 1.0),
                    .run { [weak self] in self?.sessionState.endCutscene() }
                ]), withKey: "storyCutscene")
            case .victory:
                lightingSystem.playVictory(in: self)
            default:
                break
            }
        }
    }

    func restorePlayerFromSession() {
        didNotifyGameOver = false
        resetContactTracking()
        player.position = validatedPlayerPosition(sessionState.localPlayer.worldPosition)
        player.updateEnergyBar(value: sessionState.energy)
        lastValidPlayerPosition = player.position
        lastMovementResult = .stationary(at: player.position)
        stopPlayerMovement()
        cameraNode.position = CameraFollowMath.clampedTarget(
            playerPosition: player.position,
            viewportSize: size,
            cameraScale: cameraNode.xScale,
            worldSize: gameMap.configuration.worldSize
        )
        synchronizeCandleLightWithPlayer()
        refreshStoryVisuals()
    }

    /// Converts the collision-resolved player position into the camera overlay's
    /// local coordinates. This keeps the light centered on the player even while
    /// the camera is still interpolating toward its follow target.
    func synchronizeCandleLightWithPlayer() {
        guard let candleLight, let player, candleLight.parent != nil, player.parent != nil else { return }
        // Offset the light center upward so it illuminates the character's
        // body and face rather than just the feet.
        let playerPos = player.position
        let offsetPos = CGPoint(x: playerPos.x, y: playerPos.y + 60)
        candleLight.update(lightPosition: candleLight.convert(offsetPos, from: self))
    }

    func validatedPlayerPosition(_ requestedPosition: CGPoint) -> CGPoint {
        let footprint = gameMap.configuration.playerFootprint
        if walkabilitySystem.isWalkable(
            position: requestedPosition,
            footprint: footprint
        ).isWalkable {
            return requestedPosition
        }
        if let nearest = walkabilitySystem.nearestWalkablePosition(
            to: requestedPosition,
            from: requestedPosition,
            footprint: footprint
        ) {
            return nearest
        }

        let fallbackSpawns = [
            sessionState.currentRoom.flatMap { geometryStore.configuration.spawnPoint(for: $0) },
            geometryStore.configuration.spawnPoint(for: .sleepingRoom),
            GameMapLayout.playerSpawnPosition
        ].compactMap { $0 }
        return fallbackSpawns.first {
            walkabilitySystem.isWalkable(position: $0, footprint: footprint).isWalkable
        } ?? GameMapLayout.playerSpawnPosition
    }

    private func applyPendingMapGeometry() {
        guard let update = mapGeometryUpdateSystem.drainLatestSnapshot() else { return }
        let updatedMap = update.map
        let changedCategories = update.changeSet.categories
        let previousPosition = player?.position ?? sessionState.localPlayer.worldPosition
        let previousConfiguration = gameMap.configuration
        let requiresPlayerRebuild = previousConfiguration.playerVisualRadius != updatedMap.configuration.playerVisualRadius
            || previousConfiguration.playerFootprint != updatedMap.configuration.playerFootprint
        gameMap = updatedMap
        walkabilitySystem.replaceMap(updatedMap)
        shipMapNode?.apply(map: updatedMap, changeSet: update.changeSet)
        if let doorStates = shipMapNode?.doorStates {
            walkabilitySystem.updateDoorStates(doorStates)
        }
        let canAffectPlayer = update.changeSet.isFullReplacement
            || !changedCategories.isDisjoint(with: [.room, .corridor, .wall, .doorway, .blockedArea, .object, .spawnPoint])
        if player != nil, canAffectPlayer || requiresPlayerRebuild {
            if requiresPlayerRebuild { createPlayer() }
            player.position = validatedPlayerPosition(previousPosition)
            lastValidPlayerPosition = player.position
            lastMovementResult = .stationary(at: player.position)
        }
        if update.changeSet.isFullReplacement
            || changedCategories.contains(.missionStation)
            || changedCategories.contains(.foodStation)
            || changedCategories.contains(.object) {
            createInteractiveStations()
            createFoodObject()
            createLabTable()
            createLabMonitor2()
            createLabMonitor1()
            createEngineMonitor()
            createRocketPowerOffSmoke()
        }
        if update.changeSet.isFullReplacement || changedCategories.contains(.object) {
            createAlbumBook()
        }
        if update.changeSet.isFullReplacement
            || !changedCategories.isDisjoint(with: [.room, .doorway, .missionStation, .foodStation]) {
            resetContactTracking()
        }
        refreshStoryVisuals()
        synchronizeCandleLightWithPlayer()
    }

    private func updateMapDebugTransition() {
        let enabled = DebugAvailability.isMapEditorAvailable && debugSettings.isMapDebugEnabled
        guard enabled != wasMapDebugEnabled else { return }
        wasMapDebugEnabled = enabled
        synchronizeDebugLightingVisibility()
        if enabled {
            debugEntryPlayerPosition = player?.position
            tacticalMapViewModel.closeMap()
            resetContactTracking()
            clearPencilTarget()
            resetJoystick()
            refreshStoryVisuals()
        } else if let entry = debugEntryPlayerPosition, let player {
            player.position = validatedPlayerPosition(entry)
            lastValidPlayerPosition = player.position
            sessionState.updateLocalPlayer(position: player.position)
            cameraNode.position = CameraFollowMath.clampedTarget(
                playerPosition: player.position,
                viewportSize: size,
                cameraScale: cameraNode.xScale,
                worldSize: gameMap.configuration.worldSize
            )
            debugEntryPlayerPosition = nil
            resetContactTracking()
            refreshStoryVisuals()
        }
    }

    func synchronizeDebugLightingVisibility() {
        let debugEnabled = DebugAvailability.isMapEditorAvailable && debugSettings.isMapDebugEnabled
        candleLight?.isHidden = debugEnabled
        if debugEnabled {
            cameraNode.enumerateChildNodes(withName: "lightingFlashOverlay") { node, _ in
                node.removeAllActions()
                node.removeFromParent()
            }
        }
    }

    func resetPlayerToDebugSpawn() {
        let room = sessionState.currentRoom ?? .sleepingRoom
        let spawn = geometryStore.configuration.spawnPoint(for: room)
            ?? geometryStore.configuration.spawnPoint(for: .sleepingRoom)
            ?? GameMapLayout.playerSpawnPosition
        player.position = validatedPlayerPosition(spawn)
        lastValidPlayerPosition = player.position
        if debugSettings.allowsCollisionTesting {
            sessionState.updateLocalPlayer(position: player.position)
        }
        synchronizeCandleLightWithPlayer()
    }

    func forceMapGeometryRefresh() {
        gameMap = GameMapLayout.makeRuntimeMap(
            from: geometryStore.configuration,
            revision: geometryStore.revision
        )
        walkabilitySystem.replaceMap(gameMap)
        shipMapNode?.apply(map: gameMap)
        createFoodObject()
        createAlbumBook()
        createLabTable()
        createLabMonitor2()
        createLabMonitor1()
        createEngineMonitor()
        createRocketPowerOffSmoke()
        refreshStoryVisuals()
        resetPlayerToDebugSpawnIfInvalid()
    }

    private func resetPlayerToDebugSpawnIfInvalid() {
        guard !walkabilitySystem.isWalkable(
            position: player.position,
            footprint: player.collisionFootprint
        ).isWalkable else { return }
        resetPlayerToDebugSpawn()
    }
}
