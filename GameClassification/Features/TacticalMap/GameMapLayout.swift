import CoreGraphics
import Foundation

struct StationDefinition: Identifiable, Equatable {
    let id: String
    let roomID: RoomID
    let worldPosition: CGPoint
}

enum DoorID: String, Codable, CaseIterable, Sendable {
    case cockpit
    case sleepingRoom
    case kitchen
    case engine
    case engineBackDoor
    case laboratory
    case storage

    var nodeName: String { "door-\(rawValue)" }
    var displayName: String {
        switch self {
        case .engineBackDoor: "Engine Room Back Door"
        default: "\(roomID.displayName) Door"
        }
    }

    var roomID: RoomID {
        switch self {
        case .cockpit: .cockpit
        case .sleepingRoom: .sleepingRoom
        case .kitchen: .kitchen
        case .engine, .engineBackDoor: .engine
        case .laboratory: .laboratory
        case .storage: .storage
        }
    }
}

enum ShipColliderKind: String, Equatable, Sendable {
    case hull
    case interiorWall
    case furniture
    case machinery
}

enum ShipColliderShape: Equatable {
    case rectangle(CGRect)
    case polygon([CGPoint])
    case edgeLoop([CGPoint])

    var bounds: CGRect {
        switch self {
        case let .rectangle(rect):
            rect.standardized
        case let .polygon(points), let .edgeLoop(points):
            points.reduce(into: CGRect.null) { result, point in
                result = result.union(CGRect(origin: point, size: .zero))
            }.standardized
        }
    }
}

struct ShipColliderDefinition: Identifiable, Equatable {
    let id: String
    let kind: ShipColliderKind
    let shape: ShipColliderShape
    let debugLabel: String
}

struct RoomTriggerDefinition: Identifiable, Equatable {
    var id: RoomID { roomID }
    let sourceID: String
    let roomID: RoomID
    let shape: ShipColliderShape

    var worldFrame: CGRect { shape.bounds }
}

struct SpawnPointDefinition: Identifiable, Equatable {
    var id: RoomID { roomID }
    let roomID: RoomID
    let worldPosition: CGPoint
}

/// Compiles the canonical editable configuration into the immutable shape used by
/// SpriteKit and deterministic collision. Static accessors are compatibility views
/// over `drawingSpaceDefault`; live gameplay receives a MapGeometryStore snapshot.
enum GameMapLayout {
    static let authoredArtworkSize = CGSize(width: 1_440, height: 1_080)
    static let artworkScale = CGFloat(5_504) / CGFloat(1_440)
    static let artworkOffset = CGPoint.zero

    static var defaultConfiguration: MapGeometryConfiguration {
        .drawingSpaceDefault
    }

    static var worldSize: CGSize { defaultConfiguration.worldSize.cgSize }
    static var playerRadius: CGFloat { defaultConfiguration.playerVisualRadius }
    static var playerFootprint: CollisionFootprint { defaultConfiguration.playerFootprint.runtimeValue }
    static var wallThickness: CGFloat { defaultConfiguration.wallThickness }

    /// Retained for visual dimensions and compatibility tests. Canonical map geometry
    /// itself is already expressed directly in world coordinates.
    static func scaled(_ value: CGFloat) -> CGFloat { value * artworkScale }
    static func scaled(_ size: CGSize) -> CGSize {
        CGSize(width: scaled(size.width), height: scaled(size.height))
    }

    static func worldPoint(fromImagePoint point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: worldSize.height - point.y)
    }

    static func worldRect(fromImageRect rect: CGRect) -> CGRect {
        let rect = rect.standardized
        return CGRect(
            x: rect.minX,
            y: worldSize.height - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    static func worldPoints(fromImagePoints points: [CGPoint]) -> [CGPoint] {
        points.map { worldPoint(fromImagePoint: $0) }
    }

    static func worldPoint(fromArtworkPoint point: CGPoint) -> CGPoint {
        worldPoint(fromImagePoint: CGPoint(x: scaled(point.x), y: scaled(point.y)))
    }

    static func worldRect(fromArtworkRect rect: CGRect) -> CGRect {
        worldRect(fromImageRect: CGRect(
            x: scaled(rect.minX),
            y: scaled(rect.minY),
            width: scaled(rect.width),
            height: scaled(rect.height)
        ))
    }

    static func worldPoints(fromArtworkPoints points: [CGPoint]) -> [CGPoint] {
        points.map { worldPoint(fromArtworkPoint: $0) }
    }

    static func makeRuntimeMap(
        from configuration: MapGeometryConfiguration,
        revision: Int = 0
    ) -> GameMap {
        let runtimeConfiguration = GameMapConfiguration(
            authoredArtworkSize: authoredArtworkSize,
            worldSize: configuration.worldSize.cgSize,
            artworkScale: artworkScale,
            artworkOffset: .zero,
            playerVisualRadius: configuration.playerVisualRadius,
            playerFootprint: configuration.playerFootprint.runtimeValue,
            wallThickness: configuration.wallThickness,
            walkabilityEpsilon: configuration.walkabilityEpsilon,
            targetClampStep: configuration.targetClampStep,
            targetClampMaximumRadius: configuration.targetClampMaximumRadius
        )

        let runtimeRooms = configuration.rooms
            .compactMap { room -> RoomDefinition? in
                guard room.isWalkable, room.frame.isValid, room.triggerFrame.isValid,
                      let roomID = room.roomID else { return nil }
                return RoomDefinition(
                    sourceID: room.id,
                    roomID: roomID,
                    walkableShape: freeformShape(
                        points: room.vertices,
                        fallback: room.frame.cgRect
                    ),
                    triggerShape: freeformShape(
                        points: room.triggerVertices,
                        fallback: room.triggerFrame.cgRect
                    )
                )
            }
        let runtimeCorridors = configuration.corridors
            .filter { $0.isWalkable && $0.frame.isValid }
            .map {
                CorridorDefinition(
                    id: $0.id,
                    shape: freeformShape(points: $0.vertices, fallback: $0.frame.cgRect)
                )
            }
            + configuration.rooms.compactMap { room -> CorridorDefinition? in
                guard room.isWalkable, room.roomID == nil, room.frame.isValid else { return nil }
                return CorridorDefinition(
                    id: "unbound-\(room.id)",
                    shape: freeformShape(points: room.vertices, fallback: room.frame.cgRect)
                )
            }
        let runtimeDoors = configuration.doorways.compactMap { definition -> DoorwayDefinition? in
            guard definition.isEnabled,
                  definition.frame.isValid,
                  let doorID = definition.doorID,
                  let roomID = definition.roomID else { return nil }
            return DoorwayDefinition(
                sourceID: definition.id,
                id: doorID,
                roomID: roomID,
                shape: freeformShape(
                    points: definition.vertices,
                    fallback: definition.frame.cgRect
                )
            )
        }

        let wallColliders = configuration.walls.compactMap { wall -> ShipColliderDefinition? in
            guard wall.isEnabled, wall.frame.isValid, wall.rotationRadians.isFinite else { return nil }
            let frame = wall.frame.cgRect
            return ShipColliderDefinition(
                id: wall.id,
                kind: .interiorWall,
                shape: validPolygonPoints(wall.vertices).map(ShipColliderShape.polygon)
                    ?? rotatedRectangleShape(
                        frame: frame,
                        center: CGPoint(x: frame.midX, y: frame.midY),
                        rotation: wall.rotationRadians
                    ),
                debugLabel: wall.name
            )
        }
        let blockedColliders = configuration.blockedAreas.compactMap { area -> ShipColliderDefinition? in
            guard area.isEnabled, let shape = runtimeShape(area.shape) else { return nil }
            return ShipColliderDefinition(
                id: area.id,
                kind: .hull,
                shape: shape,
                debugLabel: area.name
            )
        }
        let objectColliders = configuration.objects.compactMap { object -> ShipColliderDefinition? in
            guard object.isEnabled, object.type == .obstacle,
                  object.position.isFinite, object.size.isValid,
                  object.rotation.isFinite else { return nil }
            return ShipColliderDefinition(
                id: object.id,
                kind: .furniture,
                shape: rotatedShape(for: object),
                debugLabel: object.name
            )
        }

        let runtimeStations = configuration.stations.compactMap { station -> StationDefinition? in
            guard station.isEnabled,
                  station.kind == .mission,
                  let id = station.interactionID,
                  let roomID = station.roomID,
                  station.position.isFinite else { return nil }
            return StationDefinition(id: id, roomID: roomID, worldPosition: station.position.cgPoint)
        }
        let foodPosition = configuration.stations.first {
            $0.isEnabled && $0.kind == .food && $0.position.isFinite
        }?.position.cgPoint ?? .zero
        let runtimeSpawns = configuration.spawnPoints.compactMap { spawn -> SpawnPointDefinition? in
            guard let roomID = spawn.roomID, spawn.position.isFinite else { return nil }
            return SpawnPointDefinition(roomID: roomID, worldPosition: spawn.position.cgPoint)
        }
        let runtimeCheckpoints = configuration.checkpoints.compactMap { checkpoint -> CheckpointDefinition? in
            guard let checkpointID = checkpoint.checkpointID,
                  let roomID = checkpoint.roomID,
                  checkpoint.position.isFinite else { return nil }
            return CheckpointDefinition(
                checkpointID: checkpointID,
                roomID: roomID,
                worldPosition: checkpoint.position.cgPoint
            )
        }

        return GameMap(
            revision: revision,
            configuration: runtimeConfiguration,
            rooms: runtimeRooms,
            corridors: runtimeCorridors,
            doorways: runtimeDoors,
            wallSegments: configuration.walls.enumerated().compactMap { index, wall in
                guard wall.isEnabled, wall.vertices == nil,
                      wall.frame.isValid, wall.rotationRadians.isFinite else { return nil }
                let frame = wall.frame.cgRect
                let center = CGPoint(x: frame.midX, y: frame.midY)
                let endpoints = frame.width >= frame.height
                    ? [CGPoint(x: frame.minX, y: frame.midY), CGPoint(x: frame.maxX, y: frame.midY)]
                    : [CGPoint(x: frame.midX, y: frame.minY), CGPoint(x: frame.midX, y: frame.maxY)]
                let rotatedEndpoints = endpoints.map {
                    rotate($0, around: center, rotation: wall.rotationRadians)
                }
                return MapWallSegment(
                    id: index,
                    start: rotatedEndpoints[0],
                    end: rotatedEndpoints[1]
                )
            },
            colliders: wallColliders + blockedColliders + objectColliders,
            stations: runtimeStations,
            foodStationPosition: foodPosition,
            spawnPoints: runtimeSpawns,
            checkpoints: runtimeCheckpoints
        )
    }

    static let ship = makeRuntimeMap(from: .drawingSpaceDefault)

    static var roomDefinitions: [RoomDefinition] { ship.rooms }
    static var roomTriggerDefinitions: [RoomTriggerDefinition] { ship.roomTriggers }
    static var rooms: [MapRoom] {
        ship.rooms.map {
            MapRoom(id: $0.roomID, name: $0.roomID.displayName.uppercased(), worldFrame: $0.triggerFrame)
        }
    }
    static var corridorDefinitions: [CorridorDefinition] { ship.corridors }
    static var corridors: [CGRect] { ship.corridors.map(\.worldFrame) }
    static var walkableAreas: [CGRect] { ship.walkableFrames }
    static var spawnPoints: [SpawnPointDefinition] { ship.spawnPoints }
    static var playerSpawnPosition: CGPoint { spawnPoint(for: .sleepingRoom) }
    static var foodStationPosition: CGPoint { ship.foodStationPosition }
    static var stationDefinitions: [StationDefinition] { ship.stations }
    static var doorDefinitions: [DoorDefinition] { ship.doorways }
    static var wallSegments: [MapWallSegment] { ship.wallSegments }
    static var colliderDefinitions: [ShipColliderDefinition] { ship.colliders }

    static var blockingRectangles: [CGRect] {
        defaultConfiguration.walls.filter(\.isEnabled).map(\.rotatedBounds)
            + defaultConfiguration.objects.filter { $0.isEnabled && $0.type == .obstacle }.map(\.objectBounds)
    }

    static func room(containing point: CGPoint) -> RoomID? {
        roomTriggerDefinitions.first { $0.worldFrame.contains(point) }?.roomID
    }

    static func spawnPoint(for room: RoomID) -> CGPoint {
        ship.spawnPoint(for: room) ?? CGPoint(x: worldSize.width / 2, y: worldSize.height / 2)
    }

    static func safeSpawn(for checkpoint: CheckpointID) -> CGPoint {
        ship.checkpointPosition(for: checkpoint) ?? spawnPoint(for: .sleepingRoom)
    }

    static var defaultMarkers: [MapMarker] {
        TacticalMapMarkerFactory.make(story: StoryProgressionSystem(), includeDoors: true)
    }

    private static func runtimeShape(_ shape: MapGeometryShape) -> ShipColliderShape? {
        switch shape {
        case let .rectangle(rect):
            guard rect.isValid else { return nil }
            return .rectangle(rect.cgRect)
        case let .polygon(points):
            guard points.count >= 3, points.allSatisfy(\.isFinite) else { return nil }
            return .polygon(points.map(\.cgPoint))
        case let .edgeChain(points):
            guard points.count >= 3, points.allSatisfy(\.isFinite) else { return nil }
            return .edgeLoop(points.map(\.cgPoint))
        }
    }

    private static func rotatedShape(for object: MapObjectDefinition) -> ShipColliderShape {
        if let points = validPolygonPoints(object.vertices) {
            return .polygon(points)
        }
        let frame = object.frame
        return rotatedRectangleShape(
            frame: frame,
            center: object.position.cgPoint,
            rotation: object.rotation
        )
    }

    private static func freeformShape(
        points: [CodablePoint]?,
        fallback: CGRect
    ) -> ShipColliderShape {
        if let points = validPolygonPoints(points) {
            return .polygon(points)
        }
        return .rectangle(fallback)
    }

    private static func rotatedRectangleShape(
        frame: CGRect,
        center: CGPoint,
        rotation: Double
    ) -> ShipColliderShape {
        guard abs(rotation) > 0.000_1 else { return .rectangle(frame) }
        return .polygon(rotatedRectangleCorners(frame: frame, center: center, rotation: rotation))
    }

    private static func rotate(
        _ point: CGPoint,
        around center: CGPoint,
        rotation: Double
    ) -> CGPoint {
        let angle = CGFloat(rotation)
        let cosine = cos(angle)
        let sine = sin(angle)
        let dx = point.x - center.x
        let dy = point.y - center.y
        return CGPoint(
            x: center.x + dx * cosine - dy * sine,
            y: center.y + dx * sine + dy * cosine
        )
    }
}
