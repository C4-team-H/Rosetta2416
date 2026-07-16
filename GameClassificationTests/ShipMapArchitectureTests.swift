import SpriteKit
import Testing
import UIKit
@testable import GameClassification

@Suite("Ship map architecture")
@MainActor
struct ShipMapArchitectureTests {
    @Test("ShipMap asset and logical size are available")
    func assetAndSize() {
        #expect(UIImage(named: "ShipMap") != nil)
        #expect(GameMapLayout.worldSize == CGSize(width: 1_440, height: 1_080))
    }

    @Test("Image coordinates convert to SpriteKit coordinates")
    func coordinateConversion() {
        #expect(GameMapLayout.worldPoint(fromImagePoint: .zero) == CGPoint(x: 0, y: 1_080))
        #expect(GameMapLayout.worldPoint(fromImagePoint: CGPoint(x: 1_440, y: 1_080)) == CGPoint(x: 1_440, y: 0))
        #expect(GameMapLayout.worldRect(fromImageRect: CGRect(x: 100, y: 200, width: 300, height: 150)) == CGRect(x: 100, y: 730, width: 300, height: 150))
    }

    @Test("Room triggers and spawn points are stable and valid")
    func roomTriggersAndSpawns() {
        #expect(Set(GameMapLayout.roomTriggerDefinitions.map(\.roomID)).count == RoomID.allCases.count)
        #expect(Set(GameMapLayout.spawnPoints.map(\.roomID)).count == RoomID.allCases.count)

        for room in RoomID.allCases {
            let frame = GameMapLayout.roomTriggerDefinitions.first(where: { $0.roomID == room })!.worldFrame
            let spawn = GameMapLayout.spawnPoint(for: room)
            #expect(frame.contains(spawn))
            #expect(!GameMapLayout.blockingRectangles.contains(where: {
                $0.insetBy(dx: -GameMapLayout.playerRadius, dy: -GameMapLayout.playerRadius).contains(spawn)
            }))
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
        #expect(door.physicsBody?.categoryBitMask == PhysicsCategory.door)
        door.lock()
        #expect(door.isLocked)
        #expect(!door.open())
        #expect(door.physicsBody?.collisionBitMask == PhysicsCategory.player)

        door.unlock()
        #expect(!door.isLocked)
        #expect(door.open())
        #expect(door.isOpen)
        #expect(door.physicsBody?.categoryBitMask == PhysicsCategory.none)
        #expect(door.physicsBody?.collisionBitMask == PhysicsCategory.none)

        door.close()
        #expect(!door.isOpen)
        #expect(door.physicsBody?.categoryBitMask == PhysicsCategory.door)
        #expect(door.physicsBody?.collisionBitMask == PhysicsCategory.player)
    }

    @Test("Contact resolver is independent of body order")
    func contactBodyOrder() {
        let player = SKPhysicsBody(circleOfRadius: 15)
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
        #expect(body?.collisionBitMask == PhysicsCategory.wall | PhysicsCategory.door)
        #expect(body?.contactTestBitMask == PhysicsCategory.roomTrigger | PhysicsCategory.interactable | PhysicsCategory.door)
        #expect(body?.affectedByGravity == false)
        #expect(body?.allowsRotation == false)
        #expect(body?.usesPreciseCollisionDetection == true)
    }

    @Test("Camera target stays inside map in portrait and landscape")
    func cameraBounds() {
        let portrait = CameraFollowMath.clampedTarget(
            playerPosition: .zero,
            viewportSize: CGSize(width: 430, height: 932),
            cameraScale: 0.6,
            worldSize: GameMapLayout.worldSize
        )
        #expect(abs(portrait.x - 129) < 0.001)
        #expect(abs(portrait.y - 279.6) < 0.001)

        let landscape = CameraFollowMath.clampedTarget(
            playerPosition: CGPoint(x: 1_440, y: 1_080),
            viewportSize: CGSize(width: 1_024, height: 768),
            cameraScale: 0.6,
            worldSize: GameMapLayout.worldSize
        )
        #expect(abs(landscape.x - 1_132.8) < 0.001)
        #expect(abs(landscape.y - 849.6) < 0.001)

        let interpolated = CameraFollowMath.interpolatedPosition(
            from: .zero,
            to: CGPoint(x: 100, y: 100),
            deltaTime: 1.0 / 60.0
        )
        #expect(interpolated.x > 0 && interpolated.x < 100)
        #expect(interpolated.y > 0 && interpolated.y < 100)
    }
}
