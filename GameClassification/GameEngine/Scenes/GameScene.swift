import SpriteKit

@MainActor
protocol GameSceneEventDelegate: AnyObject {
    func gameScene(_ scene: GameScene, didEnter room: RoomID)
    func gameScene(_ scene: GameScene, didRequestObjective objectiveID: String)
    func gameSceneDidRequestFoodChallenge(_ scene: GameScene)
    func gameSceneDidReachGameOver(_ scene: GameScene)
}

final class GameScene: SKScene {
    let sessionState: GameSessionState
    let tacticalMapViewModel: TacticalMapViewModel
    weak var eventDelegate: GameSceneEventDelegate?

    let cameraNode = SKCameraNode()
    var player: SKShapeNode!
    var joystickBase: SKShapeNode!
    var joystickKnob: SKShapeNode!
    var gridContainer: SKNode?
    var actionButton: SKShapeNode?
    var foodActionButton: SKShapeNode?
    var foodObject: SKShapeNode!
    var stationNodes: [String: SKShapeNode] = [:]
    var activeStationID: String?
    var doorNodes: [String: SKShapeNode] = [:]
    var lastDeniedStationID: String?
    var lastDeniedDoorID: String?

    var isJoystickActive = false
    var joystickVector = CGPoint.zero
    var joystickActiveTouch: UITouch?
    let joystickRadius: CGFloat = 60
    let playerSpeed: CGFloat = 4

    var pencilTouch: UITouch?
    var pencilTarget: CGPoint?
    var pencilSpeedMultiplier: CGFloat = 1
    var targetMarker: SKShapeNode?
    let arrivalThreshold: CGFloat = 4

    struct Obstacle {
        let node: SKNode
        let size: CGSize
        let absPos: CGPoint
    }
    var obstacles: [Obstacle] = []
    let playerRadius: CGFloat = 15

    var candleLight: CandleLightNode?
    let lightingSystem = LightingSystem()

    private var wasMapInputSuspended = false
    private var previousUpdateTime: TimeInterval?
    private var currentRoom: RoomID?
    private var didNotifyGameOver = false

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
        camera = cameraNode
        addChild(cameraNode)
        cameraNode.setScale(0.6)

        createRegularGrid()
        createPlayer()
        createJoystick()
        createInteractiveStations()
        createFoodObject()
        createObstacles()
        enableCandleLight()
        refreshStoryVisuals()
        player.position = sessionState.localPlayer.worldPosition
        cameraNode.position = player.position
        detectRoomChange()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        createRegularGrid()
        let worldSize = GameMapLayout.worldSize
        if let player {
            player.position.x = max(playerRadius, min(worldSize.width - playerRadius, player.position.x))
            player.position.y = max(playerRadius, min(worldSize.height - playerRadius, player.position.y))
        }
        joystickBase?.position = CGPoint(x: -size.width / 2 + joystickRadius + 50, y: -size.height / 2 + joystickRadius + 70)
        positionActionButtons()
        candleLight?.position = CGPoint(x: -size.width / 2, y: -size.height / 2)
        candleLight?.resize(to: size)
    }

    override func update(_ currentTime: TimeInterval) {
        let rawDelta = previousUpdateTime.map { currentTime - $0 } ?? 0
        previousUpdateTime = currentTime
        let deltaTime = min(max(rawDelta, 0), 0.25)

        guard sessionState.phase != .gameOver, sessionState.phase != .victory else {
            resetJoystick()
            pencilTarget = nil
            return
        }
        if case .cutscene = sessionState.phase {
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
        } else {
            wasMapInputSuspended = false
        }

        let isMoving = !tacticalMapViewModel.isMapPresented
            && (pencilTarget != nil || (isJoystickActive && joystickVector != .zero))

        if isMoving, pencilTarget != nil {
            movePlayerTowardTarget()
        } else if isMoving {
            movePlayer()
        }

        if tacticalMapViewModel.shouldRunLocalSimulation && !isPaused {
            sessionState.updateEnergy(deltaTime: deltaTime, isMoving: isMoving)
            if sessionState.phase == .gameOver, !didNotifyGameOver {
                didNotifyGameOver = true
                eventDelegate?.gameSceneDidReachGameOver(self)
            }
            checkProximityToInteractiveObject()
            checkProximityToFoodObject()
            checkProximityToLockedDoor()
            detectRoomChange()
        }

        candleLight?.update(
            lightPosition: CGPoint(x: size.width / 2, y: size.height / 2),
            currentTime: currentTime
        )
        cameraNode.position = player.position
        sessionState.updateLocalPlayer(position: player.position)
        lightingSystem.apply(sessionState.sharedStory.powerState, to: self)
    }

    override func willMove(from view: SKView) {
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
        player.position = sessionState.localPlayer.worldPosition
        cameraNode.position = player.position
        refreshStoryVisuals()
    }

    private func detectRoomChange() {
        let detected = GameMapLayout.room(containing: player.position)
        guard detected != currentRoom else { return }
        currentRoom = detected
        if let detected { eventDelegate?.gameScene(self, didEnter: detected) }
    }
}
