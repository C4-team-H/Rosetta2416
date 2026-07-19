import CoreGraphics
import Testing
@testable import GameClassification

@Suite("Walkability and deterministic collision")
@MainActor
struct WalkabilityCollisionTests {
    private let openDoors = Dictionary(
        uniqueKeysWithValues: DoorID.allCases.map { ($0, DoorState.open) }
    )

    @Test("Room spawns, corridor centerlines, and open doorways are walkable")
    func authoredWalkableGeometry() {
        let system = WalkabilitySystem(map: GameMapLayout.ship, doorStates: openDoors)

        for room in RoomID.allCases {
            #expect(system.isWalkable(
                position: GameMapLayout.spawnPoint(for: room),
                footprint: GameMapLayout.playerFootprint
            ).isWalkable)
        }
        for corridor in GameMapLayout.ship.corridors {
            #expect(system.isWalkable(
                position: CGPoint(x: corridor.worldFrame.midX, y: corridor.worldFrame.midY),
                footprint: GameMapLayout.playerFootprint
            ).isWalkable)
        }
        for doorway in GameMapLayout.ship.doorways {
            #expect(system.isWalkable(
                position: doorway.worldPosition,
                footprint: GameMapLayout.playerFootprint
            ).isWalkable)
        }
    }

    @Test("Outside, furniture, and non-walkable footprint samples are blocked")
    func blockedGeometry() {
        let system = WalkabilitySystem(map: GameMapLayout.ship, doorStates: openDoors)

        #expect(system.isWalkable(
            position: .zero,
            footprint: GameMapLayout.playerFootprint
        ) == .blocked(.outsideShip))

        let obstacle = GameMapLayout.ship.colliders.first { collider in
            collider.kind == .furniture || collider.kind == .machinery
        }!
        #expect(system.isWalkable(
            position: CGPoint(x: obstacle.shape.bounds.midX, y: obstacle.shape.bounds.midY),
            footprint: GameMapLayout.playerFootprint
        ) == .blocked(.obstacle))

        let room = GameMapLayout.ship.rooms.first(where: { $0.roomID == .sleepingRoom })!
        let edgePosition = CGPoint(
            x: room.walkableFrame.minX + GameMapLayout.playerFootprint.halfWidth / 2,
            y: room.walkableFrame.midY - GameMapLayout.playerFootprint.centerOffset.y
        )
        #expect(!system.isWalkable(
            position: edgePosition,
            footprint: GameMapLayout.playerFootprint
        ).isWalkable)
    }

    @Test("Obstacle clearance can be larger than the foot navigation radius")
    func obstacleClearanceRadius() {
        let footOnly = CollisionFootprint(centerOffset: .zero, radius: 10)
        let visualClearance = CollisionFootprint(
            centerOffset: .zero,
            radius: 10,
            obstacleRadius: 45
        )
        let configuration = GameMapConfiguration(
            authoredArtworkSize: CGSize(width: 300, height: 300),
            worldSize: CGSize(width: 300, height: 300),
            artworkScale: 1,
            artworkOffset: .zero,
            playerVisualRadius: 24,
            playerFootprint: footOnly,
            wallThickness: 10,
            walkabilityEpsilon: 0.1,
            targetClampStep: 4,
            targetClampMaximumRadius: 64
        )
        let obstacle = ShipColliderDefinition(
            id: "test-obstacle",
            kind: .furniture,
            shape: .rectangle(CGRect(x: 150, y: 130, width: 40, height: 40)),
            debugLabel: "Test Obstacle"
        )
        let map = GameMap(
            configuration: configuration,
            rooms: [RoomDefinition(
                roomID: .sleepingRoom,
                walkableFrame: CGRect(x: 20, y: 20, width: 260, height: 260),
                triggerFrame: CGRect(x: 20, y: 20, width: 260, height: 260)
            )],
            corridors: [],
            doorways: [],
            wallSegments: [],
            colliders: [obstacle],
            stations: [],
            foodStationPosition: .zero,
            spawnPoints: []
        )
        let system = WalkabilitySystem(map: map)
        let nearObstacle = CGPoint(x: 110, y: 150)

        #expect(system.isWalkable(position: nearObstacle, footprint: footOnly).isWalkable)
        #expect(system.isWalkable(
            position: nearObstacle,
            footprint: visualClearance
        ) == .blocked(.obstacle))
    }

    @Test("Closed and locked doors block the footprint while open doors do not")
    func dynamicDoorWalkability() {
        let doorway = GameMapLayout.ship.doorways.first(where: { $0.id == .engine })!
        let system = WalkabilitySystem(map: GameMapLayout.ship, doorStates: openDoors)

        #expect(system.isWalkable(
            position: doorway.worldPosition,
            footprint: GameMapLayout.playerFootprint
        ).isWalkable)

        system.updateDoorState(.closed, for: doorway.id)
        #expect(system.isWalkable(
            position: doorway.worldPosition,
            footprint: GameMapLayout.playerFootprint
        ) == .blocked(.closedDoor))

        system.updateDoorState(.locked, for: doorway.id)
        #expect(system.isWalkable(
            position: doorway.worldPosition,
            footprint: GameMapLayout.playerFootprint
        ) == .blocked(.lockedDoor))

        system.updateDoorState(.open, for: doorway.id)
        #expect(system.isWalkable(
            position: doorway.worldPosition,
            footprint: GameMapLayout.playerFootprint
        ).isWalkable)
    }

    @Test("Freeform walkable polygons do not accept empty space inside their bounding box")
    func freeformRoomWalkability() {
        let footprint = CollisionFootprint(centerOffset: .zero, radius: 1)
        let configuration = GameMapConfiguration(
            authoredArtworkSize: CGSize(width: 300, height: 300),
            worldSize: CGSize(width: 300, height: 300),
            artworkScale: 1,
            artworkOffset: .zero,
            playerVisualRadius: 12,
            playerFootprint: footprint,
            wallThickness: 10,
            walkabilityEpsilon: 0.1,
            targetClampStep: 4,
            targetClampMaximumRadius: 64
        )
        let triangle: ShipColliderShape = .polygon([
            CGPoint(x: 10, y: 10),
            CGPoint(x: 290, y: 10),
            CGPoint(x: 10, y: 290)
        ])
        let map = GameMap(
            configuration: configuration,
            rooms: [RoomDefinition(
                roomID: .sleepingRoom,
                walkableShape: triangle,
                triggerShape: triangle
            )],
            corridors: [],
            doorways: [],
            wallSegments: [],
            colliders: [],
            stations: [],
            foodStationPosition: .zero,
            spawnPoints: []
        )
        let system = WalkabilitySystem(map: map)

        #expect(system.isWalkable(position: CGPoint(x: 50, y: 50), footprint: footprint).isWalkable)
        #expect(system.isWalkable(position: CGPoint(x: 250, y: 250), footprint: footprint) == .blocked(.outsideShip))
    }

    @Test("Movement resolves full steps and slides along a vertical wall")
    func verticalWallSliding() {
        let map = makeTestMap(walls: [
            MapWallSegment(id: 1, start: CGPoint(x: 100, y: 10), end: CGPoint(x: 100, y: 290))
        ])
        let walkability = WalkabilitySystem(map: map)
        let collision = CollisionSystem(walkabilitySystem: walkability)
        let result = collision.resolveMovement(
            from: CGPoint(x: 70, y: 150),
            delta: CGVector(dx: 50, dy: 30),
            footprint: map.configuration.playerFootprint
        )

        #expect(result.finalPosition.x < 90)
        #expect(result.finalPosition.y > 150)
        #expect(result.blockedAxes.contains(.horizontal))
        #expect(result.blockingReason == .wall)
    }

    @Test("Movement slides horizontally along a horizontal wall")
    func horizontalWallSliding() {
        let map = makeTestMap(walls: [
            MapWallSegment(id: 1, start: CGPoint(x: 10, y: 100), end: CGPoint(x: 290, y: 100))
        ])
        let walkability = WalkabilitySystem(map: map)
        let collision = CollisionSystem(walkabilitySystem: walkability)
        let result = collision.resolveMovement(
            from: CGPoint(x: 150, y: 130),
            delta: CGVector(dx: 30, dy: -50),
            footprint: map.configuration.playerFootprint
        )

        #expect(result.finalPosition.x > 150)
        #expect(result.finalPosition.y > 110)
        #expect(result.blockedAxes.contains(.vertical))
        #expect(result.blockingReason == .wall)
    }

    @Test("Corner collision stops both blocked axes")
    func cornerBlocking() {
        let map = makeTestMap(walls: [
            MapWallSegment(id: 1, start: CGPoint(x: 100, y: 10), end: CGPoint(x: 100, y: 290)),
            MapWallSegment(id: 2, start: CGPoint(x: 10, y: 100), end: CGPoint(x: 290, y: 100))
        ])
        let collision = CollisionSystem(walkabilitySystem: WalkabilitySystem(map: map))
        let result = collision.resolveMovement(
            from: CGPoint(x: 70, y: 70),
            delta: CGVector(dx: 50, dy: 50),
            footprint: map.configuration.playerFootprint
        )

        #expect(result.finalPosition.x < 90)
        #expect(result.finalPosition.y < 90)
        #expect(result.blockedAxes.contains(.horizontal))
        #expect(result.blockedAxes.contains(.vertical))
    }

    @Test("Large deltas cannot tunnel through a thin wall")
    func substepPreventsTunneling() {
        let map = makeTestMap(walls: [
            MapWallSegment(id: 1, start: CGPoint(x: 100, y: 10), end: CGPoint(x: 100, y: 290))
        ])
        let collision = CollisionSystem(walkabilitySystem: WalkabilitySystem(map: map))
        let result = collision.resolveMovement(
            from: CGPoint(x: 50, y: 150),
            delta: CGVector(dx: 200, dy: 0),
            footprint: map.configuration.playerFootprint
        )

        #expect(result.finalPosition.x < 90)
        #expect(result.blockedAxes.contains(.horizontal))
    }

    @Test("Movement cannot cross a corridor boundary")
    func corridorBoundaryBlocking() {
        let footprint = CollisionFootprint(centerOffset: .zero, radius: 10)
        let configuration = GameMapConfiguration(
            authoredArtworkSize: CGSize(width: 300, height: 300),
            worldSize: CGSize(width: 300, height: 300),
            artworkScale: 1,
            artworkOffset: .zero,
            playerVisualRadius: 12,
            playerFootprint: footprint,
            wallThickness: 10,
            walkabilityEpsilon: 0.1,
            targetClampStep: 4,
            targetClampMaximumRadius: 64
        )
        let corridorFrame = CGRect(x: 100, y: 20, width: 80, height: 260)
        let map = GameMap(
            configuration: configuration,
            rooms: [],
            corridors: [CorridorDefinition(id: "test-corridor", worldFrame: corridorFrame)],
            doorways: [],
            wallSegments: [],
            colliders: [],
            stations: [],
            foodStationPosition: .zero,
            spawnPoints: []
        )
        let walkability = WalkabilitySystem(map: map)
        let movement = MovementSystem(
            collisionSystem: CollisionSystem(walkabilitySystem: walkability)
        )
        let result = movement.move(
            from: CGPoint(x: corridorFrame.midX, y: corridorFrame.midY),
            direction: CGPoint(x: 1, y: 0),
            speed: 800,
            deltaTime: 0.25,
            footprint: footprint
        )

        #expect(result.finalPosition.x <= corridorFrame.maxX - footprint.radius)
        #expect(result.blockedAxes.contains(.horizontal))
        #expect(walkability.isWalkable(
            position: result.finalPosition,
            footprint: footprint
        ).isWalkable)
    }

    @Test("Invalid Pencil targets clamp nearby or reject when too far")
    func targetClamping() {
        let map = makeTestMap(walls: [
            MapWallSegment(id: 1, start: CGPoint(x: 100, y: 10), end: CGPoint(x: 100, y: 290))
        ])
        let system = WalkabilitySystem(map: map)
        let source = CGPoint(x: 50, y: 150)
        let clamped = system.nearestWalkablePosition(
            to: CGPoint(x: 100, y: 150),
            from: source,
            footprint: map.configuration.playerFootprint
        )

        #expect(clamped != nil)
        #expect(clamped!.x < 100)
        #expect(system.isWalkable(
            position: clamped!,
            footprint: map.configuration.playerFootprint
        ).isWalkable)
        #expect(system.nearestWalkablePosition(
            to: CGPoint(x: -1_000, y: -1_000),
            from: source,
            footprint: map.configuration.playerFootprint
        ) == nil)
    }

    @Test("Joystick and Pencil intents share the same movement resolver")
    func inputParity() {
        let map = makeTestMap(walls: [])
        let movement = MovementSystem(
            collisionSystem: CollisionSystem(walkabilitySystem: WalkabilitySystem(map: map))
        )
        let start = CGPoint(x: 50, y: 50)
        let direction = CGPoint(x: 0.6, y: 0.8)
        let joystick = movement.move(
            from: start,
            direction: direction,
            speed: 100,
            deltaTime: 0.1,
            footprint: map.configuration.playerFootprint
        )
        let target = CGPoint(x: start.x + direction.x * 100, y: start.y + direction.y * 100)
        let pencil = movement.move(
            from: start,
            direction: direction,
            speed: 100,
            deltaTime: 0.1,
            footprint: map.configuration.playerFootprint,
            target: target,
            arrivalThreshold: 1
        )

        #expect(joystick.finalPosition == pencil.finalPosition)
        #expect(joystick.appliedDisplacement == pencil.appliedDisplacement)
    }

    @Test("Body obstacle radius prevents crossing cockpit and engine back doors when locked or closed")
    func bodyObstacleRadiusForSpecificDoors() {
        let configuration = GameMapConfiguration(
            authoredArtworkSize: CGSize(width: 3000, height: 3000),
            worldSize: CGSize(width: 3000, height: 3000),
            artworkScale: 1,
            artworkOffset: .zero,
            playerVisualRadius: 100,
            playerFootprint: CollisionFootprint(
                centerOffset: CGPoint(x: 0, y: -60),
                radius: 20,
                obstacleRadius: 50
            ),
            wallThickness: 10,
            walkabilityEpsilon: 0.1,
            targetClampStep: 4,
            targetClampMaximumRadius: 64
        )
        let cockpitDoor = DoorwayDefinition(
            id: .cockpit,
            roomID: .cockpit,
            worldFrame: CGRect(x: 1000, y: 1000, width: 200, height: 50)
        )
        let engineBackDoor = DoorwayDefinition(
            id: .engineBackDoor,
            roomID: .engine,
            worldFrame: CGRect(x: 1500, y: 1000, width: 200, height: 50)
        )
        let otherDoor = DoorwayDefinition(
            id: .sleepingRoom,
            roomID: .sleepingRoom,
            worldFrame: CGRect(x: 2000, y: 1000, width: 200, height: 50)
        )
        
        let map = GameMap(
            configuration: configuration,
            rooms: [
                RoomDefinition(roomID: .cockpit, walkableFrame: CGRect(x: 900, y: 800, width: 400, height: 500), triggerFrame: CGRect(x: 900, y: 800, width: 400, height: 500)),
                RoomDefinition(roomID: .engine, walkableFrame: CGRect(x: 1400, y: 800, width: 400, height: 500), triggerFrame: CGRect(x: 1400, y: 800, width: 400, height: 500)),
                RoomDefinition(roomID: .sleepingRoom, walkableFrame: CGRect(x: 1900, y: 800, width: 400, height: 500), triggerFrame: CGRect(x: 1900, y: 800, width: 400, height: 500))
            ],
            corridors: [],
            doorways: [cockpitDoor, engineBackDoor, otherDoor],
            wallSegments: [],
            colliders: [],
            stations: [],
            foodStationPosition: .zero,
            spawnPoints: []
        )
        
        let doorStates: [DoorID: DoorState] = [
            .cockpit: .locked,
            .engineBackDoor: .locked,
            .sleepingRoom: .locked
        ]
        let system = WalkabilitySystem(map: map, doorStates: doorStates)
        let footprint = configuration.playerFootprint
        
        let positionAtCockpit = CGPoint(x: 1100, y: 900)
        #expect(system.isWalkable(position: positionAtCockpit, footprint: footprint) == .blocked(.lockedDoor))
        
        let positionAtEngineBack = CGPoint(x: 1600, y: 900)
        #expect(system.isWalkable(position: positionAtEngineBack, footprint: footprint) == .blocked(.lockedDoor))
        
        let positionAtOther = CGPoint(x: 2100, y: 900)
        #expect(system.isWalkable(position: positionAtOther, footprint: footprint).isWalkable)
    }

    private func makeTestMap(walls: [MapWallSegment]) -> GameMap {
        let footprint = CollisionFootprint(centerOffset: .zero, radius: 10)
        let configuration = GameMapConfiguration(
            authoredArtworkSize: CGSize(width: 300, height: 300),
            worldSize: CGSize(width: 300, height: 300),
            artworkScale: 1,
            artworkOffset: .zero,
            playerVisualRadius: 12,
            playerFootprint: footprint,
            wallThickness: 10,
            walkabilityEpsilon: 0.1,
            targetClampStep: 4,
            targetClampMaximumRadius: 64
        )
        let frame = CGRect(x: 10, y: 10, width: 280, height: 280)
        return GameMap(
            configuration: configuration,
            rooms: [RoomDefinition(roomID: .sleepingRoom, walkableFrame: frame, triggerFrame: frame)],
            corridors: [],
            doorways: [],
            wallSegments: walls,
            colliders: [],
            stations: [],
            foodStationPosition: CGPoint(x: 20, y: 20),
            spawnPoints: [SpawnPointDefinition(roomID: .sleepingRoom, worldPosition: CGPoint(x: 50, y: 50))]
        )
    }
}
