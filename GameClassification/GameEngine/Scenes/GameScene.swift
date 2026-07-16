import SpriteKit

@MainActor
protocol GameSceneEventDelegate: AnyObject {
    func gameScene(_ scene: GameScene, didEnter room: RoomID)
    func gameScene(_ scene: GameScene, didExit room: RoomID)
    func gameScene(_ scene: GameScene, didRequestObjective objectiveID: String)
    func gameSceneDidRequestFoodChallenge(_ scene: GameScene)
    func gameSceneDidReachGameOver(_ scene: GameScene)
}

final class GameScene: SKScene {
    let sessionState: GameSessionState
    let tacticalMapViewModel: TacticalMapViewModel
    weak var eventDelegate: GameSceneEventDelegate?

    let cameraNode = SKCameraNode()
    var shipMapNode: ShipMapNode?
    var player: SKShapeNode!
    var joystickBase: SKShapeNode!
    var joystickKnob: SKShapeNode!
    var gridContainer: SKNode?
    var actionButton: SKShapeNode?
    var foodActionButton: SKShapeNode?
    var foodObject: SKShapeNode!
    var stationNodes: [String: SKShapeNode] = [:]
    var activeStationID: String?
    var lastDeniedStationID: String?
    var lastDeniedDoorID: DoorID?

    var isJoystickActive = false
    var joystickVector = CGPoint.zero
    var joystickActiveTouch: UITouch?
    let joystickRadius: CGFloat = 60
    let playerSpeed: CGFloat = 240

    var pencilTouch: UITouch?
    var pencilTarget: CGPoint?
    var pencilSpeedMultiplier: CGFloat = 1
    var targetMarker: SKShapeNode?
    let arrivalThreshold: CGFloat = 4
    let playerRadius = GameMapLayout.playerRadius

    var candleLight: CandleLightNode?
    let lightingSystem = LightingSystem()

    var pendingSensorContacts: [PendingSensorContact] = []
    var roomContactTracker = RoomContactTracker()
    var interactableContactCounts: [String: Int] = [:]
    var doorContactCounts: [DoorID: Int] = [:]

    private var wasMapInputSuspended = false
    private var previousUpdateTime: TimeInterval?
    var frameDeltaTime: TimeInterval = 0
    private var didNotifyGameOver = false

    static var isShipMapDebugEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-ShipMapDebug")
        #else
        false
        #endif
    }

    init(size: CGSize, sessionState: GameSessionState, tacticalMapViewModel: TacticalMapViewModel) {
        self.sessionState = sessionState
        self.tacticalMapViewModel = tacticalMapViewModel
        super.init(size: size)
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
        cameraNode.setScale(0.6)

        createShipMap()
        createPlayer()
        createJoystick()
        createInteractiveStations()
        createFoodObject()
        enableCandleLight()
        refreshStoryVisuals()

        player.position = sessionState.localPlayer.worldPosition
        cameraNode.position = CameraFollowMath.clampedTarget(
            playerPosition: player.position,
            viewportSize: size,
            cameraScale: cameraNode.xScale,
            worldSize: GameMapLayout.worldSize
        )
        view.showsPhysics = Self.isShipMapDebugEnabled
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        joystickBase?.position = CGPoint(x: -size.width / 2 + joystickRadius + 50, y: -size.height / 2 + joystickRadius + 70)
        positionActionButtons()
        candleLight?.position = CGPoint(x: -size.width / 2, y: -size.height / 2)
        candleLight?.resize(to: size)
    }

    override func update(_ currentTime: TimeInterval) {
        let rawDelta = previousUpdateTime.map { currentTime - $0 } ?? 0
        previousUpdateTime = currentTime
        frameDeltaTime = min(max(rawDelta, 0), 0.25)

        guard sessionState.phase != .gameOver, sessionState.phase != .victory else {
            stopPlayerMovement()
            resetJoystick()
            pencilTarget = nil
            return
        }
        if case .cutscene = sessionState.phase {
            stopPlayerMovement()
            resetJoystick()
            pencilTarget = nil
            return
        }

        if tacticalMapViewModel.isMapPresented {
            if !wasMapInputSuspended {
                pencilTarget = nil
                pencilTouch = nil
                hideTargetMarker()
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

        let velocity = player.physicsBody?.velocity ?? .zero
        let isMoving = hypot(velocity.dx, velocity.dy) > 0.5

        if tacticalMapViewModel.shouldRunLocalSimulation && !isPaused {
            sessionState.updateEnergy(deltaTime: frameDeltaTime, isMoving: isMoving)
            if sessionState.phase == .gameOver, !didNotifyGameOver {
                didNotifyGameOver = true
                stopPlayerMovement()
                eventDelegate?.gameSceneDidReachGameOver(self)
            }
            checkProximityToInteractiveObject()
            checkProximityToFoodObject()
            checkProximityToLockedDoor()
        }

        candleLight?.update(
            lightPosition: CGPoint(x: size.width / 2, y: size.height / 2),
            currentTime: currentTime
        )
        lightingSystem.apply(sessionState.sharedStory.powerState, to: self)
    }

    override func didSimulatePhysics() {
        super.didSimulatePhysics()
        processPendingPhysicsContacts()

        let target = CameraFollowMath.clampedTarget(
            playerPosition: player.position,
            viewportSize: size,
            cameraScale: cameraNode.xScale,
            worldSize: GameMapLayout.worldSize
        )
        cameraNode.position = CameraFollowMath.interpolatedPosition(
            from: cameraNode.position,
            to: target,
            deltaTime: frameDeltaTime
        )
        sessionState.updateLocalPlayer(position: player.position)
    }

    override func willMove(from view: SKView) {
        stopPlayerMovement()
        physicsWorld.contactDelegate = nil
        tacticalMapViewModel.closeMap()
        sessionState.endGameplay()
        super.willMove(from: view)
    }

    func applyStoryEffects(_ effects: [StoryEffect]) {
        guard !effects.isEmpty else { return }
        refreshStoryVisuals()
        for effect in effects {
            switch effect {
            case let .powerChanged(power):
                lightingSystem.transition(to: power, in: self)
            case let .objectiveCompleted(id):
                animateCompletedStation(id: id)
            case .doorAccessChanged, .stationVisualChanged:
                refreshStoryVisuals()
            case .cutscene:
                stopPlayerMovement()
                resetJoystick()
                pencilTarget = nil
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
        player.position = sessionState.localPlayer.worldPosition
        stopPlayerMovement()
        cameraNode.position = CameraFollowMath.clampedTarget(
            playerPosition: player.position,
            viewportSize: size,
            cameraScale: cameraNode.xScale,
            worldSize: GameMapLayout.worldSize
        )
        refreshStoryVisuals()
    }
}
