import SpriteKit
import Testing
import UIKit
@testable import GameClassification

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

    @Test("Door state deterministically controls collision masks")
    func doorState() {
        let definition = GameMapLayout.doorDefinitions.first(where: { $0.id == .engine })!
        let door = ShipDoorNode(definition: definition)

        #expect(!door.isOpen)
        #expect(door.state == .closed)
        #expect(door.physicsBody?.categoryBitMask == PhysicsCategory.closedDoor)
        door.lock()
        #expect(door.isLocked)
        #expect(door.state == .locked)
        #expect(!door.open())
        #expect(door.physicsBody?.collisionBitMask == PhysicsCategory.player)

        door.unlock()
        #expect(!door.isLocked)
        #expect(door.state == .closed)
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
        #expect(body?.contactTestBitMask == PhysicsCategory.roomTrigger | PhysicsCategory.interaction | PhysicsCategory.closedDoor)
        #expect(body?.affectedByGravity == false)
        #expect(body?.allowsRotation == false)
        #expect(body?.usesPreciseCollisionDetection == true)
        #expect(abs(
            (scene.player.path?.boundingBox.width ?? 0) - GameMapLayout.playerRadius * 2
        ) < 0.001)
        #expect(abs(scene.playerSpeed - GameMapLayout.scaled(240)) < 0.001)
        #expect(abs(scene.arrivalThreshold - GameMapLayout.scaled(4)) < 0.001)
        #expect(scene.player.collisionFootprint == GameMapLayout.playerFootprint)
        #expect(abs(scene.player.collisionFootprint.radius - GameMapLayout.scaled(12)) < 0.001)
        #expect(abs(scene.player.collisionFootprint.centerOffset.y + GameMapLayout.scaled(3)) < 0.001)
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
