import CoreGraphics
import Foundation

struct GameMapConfiguration: Equatable {
    let authoredArtworkSize: CGSize
    let worldSize: CGSize
    let artworkScale: CGFloat
    let artworkOffset: CGPoint
    let playerVisualRadius: CGFloat
    let playerFootprint: CollisionFootprint
    let wallThickness: CGFloat
    let walkabilityEpsilon: CGFloat
    let targetClampStep: CGFloat
    let targetClampMaximumRadius: CGFloat
}

enum WalkableAreaType: String, Codable, Equatable, Sendable {
    case room
    case corridor
    case doorway
}

enum BlockedAreaType: String, Codable, Equatable, Sendable {
    case outsideShip
    case wall
    case obstacle
    case closedDoor
    case lockedDoor
    case invalid
}

enum DoorState: String, Codable, Equatable, Sendable {
    case locked
    case closed
    case open

    var blocksMovement: Bool { self != .open }
}

struct CollisionFootprint: Equatable {
    let centerOffset: CGPoint
    let radius: CGFloat

    var validationOffsets: [CGPoint] {
        [
            centerOffset,
            CGPoint(x: centerOffset.x - radius, y: centerOffset.y),
            CGPoint(x: centerOffset.x + radius, y: centerOffset.y),
            CGPoint(x: centerOffset.x, y: centerOffset.y + radius),
            CGPoint(x: centerOffset.x, y: centerOffset.y - radius)
        ]
    }

    func center(at playerPosition: CGPoint) -> CGPoint {
        CGPoint(
            x: playerPosition.x + centerOffset.x,
            y: playerPosition.y + centerOffset.y
        )
    }

    func samplePoints(at playerPosition: CGPoint) -> [CGPoint] {
        validationOffsets.map { offset in
            CGPoint(x: playerPosition.x + offset.x, y: playerPosition.y + offset.y)
        }
    }
}

enum WalkabilityResult: Equatable {
    case walkable(WalkableAreaType)
    case blocked(BlockedAreaType)

    var isWalkable: Bool {
        if case .walkable = self { return true }
        return false
    }

    var blockedReason: BlockedAreaType? {
        guard case let .blocked(reason) = self else { return nil }
        return reason
    }
}

struct RoomDefinition: Identifiable, Equatable {
    var id: RoomID { roomID }
    let sourceID: String
    let roomID: RoomID
    let walkableShape: ShipColliderShape
    let triggerShape: ShipColliderShape

    var walkableFrame: CGRect { walkableShape.bounds }
    var triggerFrame: CGRect { triggerShape.bounds }

    init(
        sourceID: String? = nil,
        roomID: RoomID,
        walkableFrame: CGRect,
        triggerFrame: CGRect
    ) {
        self.sourceID = sourceID ?? "room-\(roomID.rawValue)"
        self.roomID = roomID
        walkableShape = .rectangle(walkableFrame)
        triggerShape = .rectangle(triggerFrame)
    }

    init(
        sourceID: String? = nil,
        roomID: RoomID,
        walkableShape: ShipColliderShape,
        triggerShape: ShipColliderShape
    ) {
        self.sourceID = sourceID ?? "room-\(roomID.rawValue)"
        self.roomID = roomID
        self.walkableShape = walkableShape
        self.triggerShape = triggerShape
    }
}

struct CorridorDefinition: Identifiable, Equatable {
    let id: String
    let shape: ShipColliderShape

    var worldFrame: CGRect { shape.bounds }

    init(id: String, worldFrame: CGRect) {
        self.id = id
        shape = .rectangle(worldFrame)
    }

    init(id: String, shape: ShipColliderShape) {
        self.id = id
        self.shape = shape
    }
}

struct DoorwayDefinition: Identifiable, Equatable {
    let id: DoorID
    let sourceID: String
    let roomID: RoomID
    let shape: ShipColliderShape

    var worldFrame: CGRect { shape.bounds }

    init(sourceID: String? = nil, id: DoorID, roomID: RoomID, worldFrame: CGRect) {
        self.id = id
        self.sourceID = sourceID ?? "door-\(id.rawValue)"
        self.roomID = roomID
        shape = .rectangle(worldFrame)
    }

    init(sourceID: String? = nil, id: DoorID, roomID: RoomID, shape: ShipColliderShape) {
        self.id = id
        self.sourceID = sourceID ?? "door-\(id.rawValue)"
        self.roomID = roomID
        self.shape = shape
    }

    var worldPosition: CGPoint {
        CGPoint(x: worldFrame.midX, y: worldFrame.midY)
    }

    var size: CGSize { worldFrame.size }
}

typealias DoorDefinition = DoorwayDefinition

struct CheckpointDefinition: Identifiable, Equatable {
    var id: CheckpointID { checkpointID }
    let checkpointID: CheckpointID
    let roomID: RoomID
    let worldPosition: CGPoint
}

/// Immutable, revision-tagged runtime geometry compiled from MapGeometryConfiguration.
/// It is deliberately a derived snapshot; editable coordinates only live in MapGeometryStore.
struct GameMap {
    let revision: Int
    let configuration: GameMapConfiguration
    let rooms: [RoomDefinition]
    let corridors: [CorridorDefinition]
    let doorways: [DoorwayDefinition]
    let wallSegments: [MapWallSegment]
    let colliders: [ShipColliderDefinition]
    let stations: [StationDefinition]
    let foodStationPosition: CGPoint
    let spawnPoints: [SpawnPointDefinition]
    let checkpoints: [CheckpointDefinition]

    init(
        revision: Int = 0,
        configuration: GameMapConfiguration,
        rooms: [RoomDefinition],
        corridors: [CorridorDefinition],
        doorways: [DoorwayDefinition],
        wallSegments: [MapWallSegment],
        colliders: [ShipColliderDefinition],
        stations: [StationDefinition],
        foodStationPosition: CGPoint,
        spawnPoints: [SpawnPointDefinition],
        checkpoints: [CheckpointDefinition] = []
    ) {
        self.revision = revision
        self.configuration = configuration
        self.rooms = rooms
        self.corridors = corridors
        self.doorways = doorways
        self.wallSegments = wallSegments
        self.colliders = colliders
        self.stations = stations
        self.foodStationPosition = foodStationPosition
        self.spawnPoints = spawnPoints
        self.checkpoints = checkpoints
    }

    var roomTriggers: [RoomTriggerDefinition] {
        rooms.map {
            RoomTriggerDefinition(
                sourceID: $0.sourceID,
                roomID: $0.roomID,
                shape: $0.triggerShape
            )
        }
    }

    var walkableFrames: [CGRect] {
        rooms.map(\.walkableFrame) + corridors.map(\.worldFrame)
    }

    func spawnPoint(for room: RoomID) -> CGPoint? {
        spawnPoints.first(where: { $0.roomID == room })?.worldPosition
    }

    func checkpointPosition(for checkpoint: CheckpointID) -> CGPoint? {
        checkpoints.first(where: { $0.checkpointID == checkpoint })?.worldPosition
    }
}
