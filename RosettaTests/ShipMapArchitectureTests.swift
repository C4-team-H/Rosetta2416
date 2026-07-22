import SpriteKit
import Testing
import UIKit
@testable import Rosetta

@Suite("Ship map architecture")
@MainActor
struct ShipMapArchitectureTests {
    @Test("ShipMap asset and logical size are available")
    func assetAndSize() {
        let image = UIImage(named: "ShipMap")
        #expect(image != nil)
        #expect(image?.size == CGSize(width: 5_504, height: 4_128))
        #expect(GameMapLayout.worldSize == CGSize(width: 5_504, height: 4_128))
        #expect(abs(GameMapLayout.artworkScale - (5_504.0 / 1_440.0)) < 0.001)
        #expect(GameMapLayout.ship.configuration.worldSize == GameMapLayout.worldSize)
        #expect(GameMapLayout.ship.rooms.count == RoomID.allCases.count)
        #expect(GameMapLayout.ship.doorways.count == DoorID.allCases.count)
    }

    @Test("Image coordinates convert to SpriteKit coordinates")
    func coordinateConversion() {
        #expect(GameMapLayout.worldPoint(fromImagePoint: .zero) == CGPoint(x: 0, y: 4_128))
        #expect(GameMapLayout.worldPoint(fromImagePoint: CGPoint(x: 5_504, y: 4_128)) == CGPoint(x: 5_504, y: 0))
        #expect(GameMapLayout.worldRect(fromImageRect: CGRect(x: 100, y: 200, width: 300, height: 150)) == CGRect(x: 100, y: 3_778, width: 300, height: 150))

        #expect(GameMapLayout.artworkOffset == .zero)
        #expect(GameMapLayout.worldPoint(fromArtworkPoint: CGPoint(x: 1_440, y: 1_080)) == CGPoint(x: 5_504, y: 0))
        let scaledRect = GameMapLayout.worldRect(fromArtworkRect: CGRect(x: 100, y: 200, width: 300, height: 150))
        #expect(abs(scaledRect.minX - GameMapLayout.scaled(100)) < 0.001)
        #expect(abs(scaledRect.minY - GameMapLayout.scaled(730)) < 0.001)
        #expect(abs(scaledRect.width - GameMapLayout.scaled(300)) < 0.001)
        #expect(abs(scaledRect.height - GameMapLayout.scaled(150)) < 0.001)
    }

    @Test("Room triggers and spawn points are stable and valid")
    func roomTriggersAndSpawns() {
        let walkability = WalkabilitySystem(
            map: GameMapLayout.ship,
            doorStates: Dictionary(uniqueKeysWithValues: DoorID.allCases.map { ($0, .open) })
        )
        #expect(Set(GameMapLayout.roomTriggerDefinitions.map(\.roomID)).count == RoomID.allCases.count)
        #expect(Set(GameMapLayout.spawnPoints.map(\.roomID)).count == RoomID.allCases.count)

        for room in RoomID.allCases {
            let frame = GameMapLayout.roomTriggerDefinitions.first(where: { $0.roomID == room })!.worldFrame
            let spawn = GameMapLayout.spawnPoint(for: room)
            #expect(frame.contains(spawn))
            #expect(walkability.isWalkable(
                position: spawn,
                footprint: GameMapLayout.playerFootprint
            ).isWalkable)
        }

        for firstIndex in GameMapLayout.roomTriggerDefinitions.indices {
            for secondIndex in GameMapLayout.roomTriggerDefinitions.indices where secondIndex > firstIndex {
                #expect(!GameMapLayout.roomTriggerDefinitions[firstIndex].worldFrame.intersects(
                    GameMapLayout.roomTriggerDefinitions[secondIndex].worldFrame
                ))
            }
        }
    }

    @Test("Collider and door identifiers are unique")
    func uniqueIdentifiers() {
        let colliderIDs = GameMapLayout.colliderDefinitions.map(\.id)
        let doorIDs = GameMapLayout.doorDefinitions.map(\.id)
        #expect(Set(colliderIDs).count == colliderIDs.count)
        #expect(Set(doorIDs).count == DoorID.allCases.count)
    }

    @Test("Locked door denial uses a tight proximity radius")
    func lockedDoorDeniedRadius() {
        #expect(GameplayInteractionTuning.lockedDoorDeniedRadius == GameMapLayout.scaled(36))
        #expect(GameplayInteractionTuning.lockedDoorDeniedRadius < GameMapLayout.scaled(88))
        #expect(GameplayInteractionTuning.lockedDoorDeniedRadius > GameMapLayout.playerRadius)
    }

    @Test("Door state deterministically controls collision masks")
    func doorState() {
        let definition = GameMapLayout.doorDefinitions.first(where: { $0.id == .engine })!
        let door = ShipDoorNode(definition: definition)
        let lockedVisuals = door.childNode(withName: "lockedDoorVisualRoot")

        #expect(!door.isOpen)
        #expect(door.state == .closed)
        #expect(door.physicsBody?.categoryBitMask == PhysicsCategory.closedDoor)
        #expect(lockedVisuals?.isHidden == true)
        door.lock()
        #expect(door.isLocked)
        #expect(door.state == .locked)
        #expect(!door.open())
        #expect(door.physicsBody?.collisionBitMask == PhysicsCategory.player)
        #expect(lockedVisuals?.isHidden == false)
        #expect(door.childNode(withName: "//lockedDoorGlow") != nil)
        #expect(door.childNode(withName: "//lockedDoorInnerPanel") != nil)
        #expect(door.childNode(withName: "//lockedDoorLockGlyph") != nil)
        #expect(door.childNode(withName: "//lockedDoorStatusLightLeft") != nil)
        #expect(door.childNode(withName: "//lockedDoorStatusLightRight") != nil)
        #expect(door.childNode(withName: "//lockedDoorStatusLights")?.hasActions() == true)
        #expect(door.childNode(withName: "//lockedDoorRivet-0") != nil)

        door.unlock()
        #expect(!door.isLocked)
        #expect(door.state == .closed)
        #expect(lockedVisuals?.isHidden == true)
        #expect(door.open())
        #expect(door.isOpen)
        #expect(door.state == .open)
        #expect(door.physicsBody?.categoryBitMask == PhysicsCategory.none)
        #expect(door.physicsBody?.collisionBitMask == PhysicsCategory.none)

        door.close()
        #expect(!door.isOpen)
        #expect(door.state == .closed)
        #expect(door.physicsBody?.categoryBitMask == PhysicsCategory.closedDoor)
        #expect(door.physicsBody?.collisionBitMask == PhysicsCategory.player)
    }

    @Test("Contact resolver is independent of body order")
    func contactBodyOrder() {
        let player = SKPhysicsBody(circleOfRadius: GameMapLayout.playerRadius)
        player.categoryBitMask = PhysicsCategory.player
        let trigger = SKPhysicsBody(rectangleOf: CGSize(width: 40, height: 40))
        trigger.categoryBitMask = PhysicsCategory.roomTrigger

        #expect(PhysicsContactResolver.otherBody(
            bodyA: player,
            bodyB: trigger,
            pairedWith: PhysicsCategory.roomTrigger
        ) === trigger)
        #expect(PhysicsContactResolver.otherBody(
            bodyA: trigger,
            bodyB: player,
            pairedWith: PhysicsCategory.roomTrigger
        ) === trigger)
    }

    @Test("Room contacts are reference counted")
    func roomContactReferenceCounting() {
        var tracker = RoomContactTracker()
        tracker.begin(room: .sleepingRoom, triggerID: "sleeping")
        tracker.begin(room: .sleepingRoom, triggerID: "sleeping")
        #expect(tracker.resolvedRoom == .sleepingRoom)

        tracker.end(room: .sleepingRoom, triggerID: "sleeping")
        #expect(tracker.resolvedRoom == .sleepingRoom)
        tracker.end(room: .sleepingRoom, triggerID: "sleeping")
        #expect(tracker.resolvedRoom == nil)

        tracker.begin(room: .laboratory, triggerID: "lab")
        #expect(tracker.resolvedRoom == .laboratory)
    }

    @Test("Player body uses top-down collision masks")
    func playerPhysicsBody() {
        let session = GameSessionState(localPlayer: PlayerState(
            id: "test-player",
            name: "Test",
            worldPosition: GameMapLayout.playerSpawnPosition,
            isConnected: true
        ))
        let mapViewModel = TacticalMapViewModel(sessionState: session)
        let scene = GameScene(size: CGSize(width: 1_024, height: 768), sessionState: session, tacticalMapViewModel: mapViewModel)
        scene.createShipMap()
        scene.createPlayer()

        let body = scene.player.physicsBody
        #expect(body?.categoryBitMask == PhysicsCategory.player)
        #expect(body?.collisionBitMask == PhysicsCategory.wall | PhysicsCategory.closedDoor)
        #expect(body?.contactTestBitMask == PhysicsCategory.none)
        #expect(body?.affectedByGravity == false)
        #expect(body?.allowsRotation == false)
        #expect(body?.friction == 0)
        #expect(body?.restitution == 0)
        #expect(body?.linearDamping == 0)
        #expect(body?.usesPreciseCollisionDetection == true)
        let characterBounds = scene.player.characterFootprintBounds
        let baseCharacterBounds = PlayerNode.makeCharacterBounds(
            visualRadius: GameMapLayout.ship.configuration.playerVisualRadius,
            textureSize: scene.player.characterSprite.texture?.size()
        )
        #expect(abs(characterBounds.width - baseCharacterBounds.width) < 0.001)
        #expect(abs(characterBounds.height - baseCharacterBounds.height) < 0.001)
        #expect(abs(characterBounds.width - scene.player.characterSprite.size.width) < 0.001)
        #expect(abs(characterBounds.height - scene.player.characterSprite.size.height) < 0.001)
        #expect(scene.player.characterSprite.xScale == 1)
        #expect(scene.player.characterSprite.yScale == 1)
        let physicsBounds = scene.player.path?.boundingBox ?? .zero
        let configuredFootprintBounds = PlayerNode.makeFootprintBounds(
            footprint: scene.player.collisionFootprint
        )
        #expect(abs(physicsBounds.minX - scene.player.footprintBounds.minX) < 0.001)
        #expect(abs(physicsBounds.minY - scene.player.footprintBounds.minY) < 0.001)
        #expect(abs(physicsBounds.width - scene.player.footprintBounds.width) < 0.001)
        #expect(abs(physicsBounds.height - scene.player.footprintBounds.height) < 0.001)
        #expect(scene.player.footprintBounds == configuredFootprintBounds)
        #expect(scene.player.navigationFootprint.centerOffset == scene.player.collisionFootprint.centerOffset)
        #expect(scene.player.navigationFootprint.size == scene.player.collisionFootprint.size)
        #expect(scene.player.navigationFootprint.radius == scene.player.collisionFootprint.radius)
        #expect(scene.player.navigationFootprint.obstacleRadius == scene.player.collisionFootprint.obstacleRadius)
        #expect(scene.player.navigationFootprint.obstacleRadius >= scene.player.collisionFootprint.radius)
        let sensorBody = scene.player.interactionSensor.physicsBody
        #expect(sensorBody?.categoryBitMask == PhysicsCategory.playerSensor)
        #expect(sensorBody?.collisionBitMask == PhysicsCategory.none)
        #expect(abs(scene.playerSpeed - GameMapLayout.scaled(80)) < 0.001)
        #expect(abs(scene.arrivalThreshold - GameMapLayout.scaled(4)) < 0.001)
        #expect(scene.player.collisionFootprint == GameMapLayout.playerFootprint)
    }

    @Test("Footprint and character visual sizes are configured independently")
    func playerFootprintAndVisualSizeAreIndependent() {
        var smallFootprintConfiguration = MapGeometryConfiguration.drawingSpaceDefault
        smallFootprintConfiguration.playerFootprint.width = 80
        smallFootprintConfiguration.playerFootprint.height = 40
        smallFootprintConfiguration.playerFootprint.obstacleRadius = 52
        var largeFootprintConfiguration = smallFootprintConfiguration
        largeFootprintConfiguration.playerFootprint.width = 220
        largeFootprintConfiguration.playerFootprint.height = 120
        largeFootprintConfiguration.playerFootprint.obstacleRadius = 132

        let smallFootprintPlayer = PlayerNode(
            configuration: GameMapLayout.makeRuntimeMap(from: smallFootprintConfiguration).configuration,
            debugEnabled: false
        )
        let largeFootprintPlayer = PlayerNode(
            configuration: GameMapLayout.makeRuntimeMap(from: largeFootprintConfiguration).configuration,
            debugEnabled: false
        )

        #expect(smallFootprintPlayer.characterSprite.size == largeFootprintPlayer.characterSprite.size)
        #expect(smallFootprintPlayer.characterFootprintBounds == largeFootprintPlayer.characterFootprintBounds)
        #expect(smallFootprintPlayer.footprintBounds != largeFootprintPlayer.footprintBounds)
        #expect(smallFootprintPlayer.footprintBounds.width == 80)
        #expect(smallFootprintPlayer.footprintBounds.height == 40)
        #expect(largeFootprintPlayer.footprintBounds.width == 220)
        #expect(largeFootprintPlayer.footprintBounds.height == 120)
        #expect(smallFootprintPlayer.navigationFootprint.obstacleRadius == 52)
        #expect(largeFootprintPlayer.navigationFootprint.obstacleRadius == 132)

        var smallVisualConfiguration = smallFootprintConfiguration
        smallVisualConfiguration.playerVisualRadius = 60
        var largeVisualConfiguration = smallFootprintConfiguration
        largeVisualConfiguration.playerVisualRadius = 180

        let smallVisualPlayer = PlayerNode(
            configuration: GameMapLayout.makeRuntimeMap(from: smallVisualConfiguration).configuration,
            debugEnabled: false
        )
        let largeVisualPlayer = PlayerNode(
            configuration: GameMapLayout.makeRuntimeMap(from: largeVisualConfiguration).configuration,
            debugEnabled: false
        )

        #expect(smallVisualPlayer.characterSprite.size != largeVisualPlayer.characterSprite.size)
        #expect(smallVisualPlayer.footprintBounds == largeVisualPlayer.footprintBounds)
        #expect(smallVisualPlayer.navigationFootprint.obstacleRadius == largeVisualPlayer.navigationFootprint.obstacleRadius)
    }

    @Test("Velocity movement preserves the current character size")
    func playerVelocityPreservesVisualSize() {
        let player = PlayerNode(
            configuration: GameMapLayout.ship.configuration,
            debugEnabled: false
        )
        let currentSize = player.characterSprite.size

        player.setMovementVelocity(direction: CGPoint(x: 1, y: 1), speed: 120)

        #expect(player.characterSprite.size == currentSize)
        #expect(abs(hypot(
            player.physicsBody?.velocity.dx ?? 0,
            player.physicsBody?.velocity.dy ?? 0
        ) - 120) < 0.001)
    }

    @Test("Foot navigation footprint starts inside every authored room")
    func navigationFootprintAtSpawns() {
        let player = PlayerNode(
            configuration: GameMapLayout.ship.configuration,
            debugEnabled: false
        )
        let walkability = WalkabilitySystem(
            map: GameMapLayout.ship,
            doorStates: Dictionary(uniqueKeysWithValues: DoorID.allCases.map { ($0, .open) })
        )

        for room in RoomID.allCases {
            let result = walkability.isWalkable(
                position: GameMapLayout.spawnPoint(for: room),
                footprint: player.navigationFootprint
            )
            #expect(
                result.isWalkable,
                "Expected \(room.displayName) spawn to be walkable, got \(result)"
            )
        }
    }

    @Test("Camera target stays inside map in portrait and landscape")
    func cameraBounds() {
        #expect(abs(
            GameScene.gameplayCameraScale / GameMapLayout.artworkScale - 0.266_666_666_7
        ) < 0.001)

        let portrait = CameraFollowMath.clampedTarget(
            playerPosition: .zero,
            viewportSize: CGSize(width: 430, height: 932),
            cameraScale: GameScene.gameplayCameraScale,
            worldSize: GameMapLayout.worldSize
        )
        #expect(abs(portrait.x - GameMapLayout.scaled(57.333_333_3)) < 0.001)
        #expect(abs(portrait.y - GameMapLayout.scaled(124.266_666_7)) < 0.001)

        let landscape = CameraFollowMath.clampedTarget(
            playerPosition: CGPoint(x: GameMapLayout.worldSize.width, y: GameMapLayout.worldSize.height),
            viewportSize: CGSize(width: 1_024, height: 768),
            cameraScale: GameScene.gameplayCameraScale,
            worldSize: GameMapLayout.worldSize
        )
        #expect(abs(landscape.x - GameMapLayout.scaled(1_303.466_666_7)) < 0.001)
        #expect(abs(landscape.y - GameMapLayout.scaled(977.6)) < 0.001)

        let interpolated = CameraFollowMath.interpolatedPosition(
            from: .zero,
            to: CGPoint(x: 100, y: 100),
            deltaTime: 1.0 / 60.0
        )
        #expect(interpolated.x > 0 && interpolated.x < 100)
        #expect(interpolated.y > 0 && interpolated.y < 100)
    }
}
