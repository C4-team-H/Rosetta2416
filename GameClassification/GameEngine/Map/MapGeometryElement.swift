import CoreGraphics
import Foundation

enum MapElementCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case room
    case corridor
    case wall
    case doorway
    case blockedArea
    case object
    case missionStation
    case foodStation
    case spawnPoint
    case checkpoint
}

struct MapElementID: Codable, Equatable, Hashable, Identifiable, Sendable {
    let category: MapElementCategory
    let rawValue: String

    var id: String { "\(category.rawValue):\(rawValue)" }
}

enum MapEditorSelection: Equatable, Hashable, Sendable {
    case room(String)
    case corridor(String)
    case wall(String)
    case doorway(String)
    case blockedArea(String)
    case object(String)
    case missionStation(String)
    case foodStation(String)
    case spawnPoint(String)
    case checkpoint(String)

    var elementID: MapElementID {
        switch self {
        case let .room(id): MapElementID(category: .room, rawValue: id)
        case let .corridor(id): MapElementID(category: .corridor, rawValue: id)
        case let .wall(id): MapElementID(category: .wall, rawValue: id)
        case let .doorway(id): MapElementID(category: .doorway, rawValue: id)
        case let .blockedArea(id): MapElementID(category: .blockedArea, rawValue: id)
        case let .object(id): MapElementID(category: .object, rawValue: id)
        case let .missionStation(id): MapElementID(category: .missionStation, rawValue: id)
        case let .foodStation(id): MapElementID(category: .foodStation, rawValue: id)
        case let .spawnPoint(id): MapElementID(category: .spawnPoint, rawValue: id)
        case let .checkpoint(id): MapElementID(category: .checkpoint, rawValue: id)
        }
    }

    init(_ id: MapElementID) {
        switch id.category {
        case .room: self = .room(id.rawValue)
        case .corridor: self = .corridor(id.rawValue)
        case .wall: self = .wall(id.rawValue)
        case .doorway: self = .doorway(id.rawValue)
        case .blockedArea: self = .blockedArea(id.rawValue)
        case .object: self = .object(id.rawValue)
        case .missionStation: self = .missionStation(id.rawValue)
        case .foodStation: self = .foodStation(id.rawValue)
        case .spawnPoint: self = .spawnPoint(id.rawValue)
        case .checkpoint: self = .checkpoint(id.rawValue)
        }
    }
}

enum MapGeometryElement: Equatable, Identifiable {
    case room(MapRoomDefinition)
    case corridor(MapCorridorDefinition)
    case wall(MapWallDefinition)
    case doorway(MapDoorwayDefinition)
    case blockedArea(MapBlockedAreaDefinition)
    case object(MapObjectDefinition)
    case station(MapStationDefinition)
    case spawnPoint(MapSpawnPointDefinition)
    case checkpoint(MapCheckpointDefinition)

    var id: MapElementID {
        switch self {
        case let .room(value): MapElementID(category: .room, rawValue: value.id)
        case let .corridor(value): MapElementID(category: .corridor, rawValue: value.id)
        case let .wall(value): MapElementID(category: .wall, rawValue: value.id)
        case let .doorway(value): MapElementID(category: .doorway, rawValue: value.id)
        case let .blockedArea(value): MapElementID(category: .blockedArea, rawValue: value.id)
        case let .object(value): MapElementID(category: .object, rawValue: value.id)
        case let .station(value): MapElementID(category: value.kind == .food ? .foodStation : .missionStation, rawValue: value.id)
        case let .spawnPoint(value): MapElementID(category: .spawnPoint, rawValue: value.id)
        case let .checkpoint(value): MapElementID(category: .checkpoint, rawValue: value.id)
        }
    }

    var name: String {
        switch self {
        case let .room(value): value.name
        case let .corridor(value): value.name
        case let .wall(value): value.name
        case let .doorway(value): value.name
        case let .blockedArea(value): value.name
        case let .object(value): value.name
        case let .station(value): value.name
        case let .spawnPoint(value): value.name
        case let .checkpoint(value): value.name
        }
    }

    var isRequired: Bool {
        switch self {
        case let .room(value): value.isRequired
        case let .corridor(value): value.isRequired
        case let .wall(value): value.isRequired
        case let .doorway(value): value.isRequired
        case let .blockedArea(value): value.isRequired
        case let .object(value): value.isRequired
        case let .station(value): value.isRequired
        case let .spawnPoint(value): value.isRequired
        case let .checkpoint(value): value.isRequired
        }
    }

    var worldFrame: CGRect? {
        switch self {
        case let .room(value): value.walkableBounds
        case let .corridor(value): value.walkableBounds
        case let .wall(value): value.rotatedBounds
        case let .doorway(value): value.doorwayBounds
        case let .blockedArea(value): value.shape.bounds
        case let .object(value): value.objectBounds
        case .station, .spawnPoint, .checkpoint: nil
        }
    }

    var freeformVertices: [CGPoint]? {
        switch self {
        case let .room(value): validPolygonPoints(value.vertices)
        case let .corridor(value): validPolygonPoints(value.vertices)
        case let .wall(value): validPolygonPoints(value.vertices)
        case let .doorway(value): validPolygonPoints(value.vertices)
        case let .object(value): validPolygonPoints(value.vertices)
        default: nil
        }
    }

    var freeformPointSets: [[CodablePoint]] {
        switch self {
        case let .room(value): [value.vertices, value.triggerVertices].compactMap { $0 }
        case let .corridor(value): [value.vertices].compactMap { $0 }
        case let .wall(value): [value.vertices].compactMap { $0 }
        case let .doorway(value): [value.vertices].compactMap { $0 }
        case let .object(value): [value.vertices].compactMap { $0 }
        default: []
        }
    }

    var worldPosition: CGPoint {
        switch self {
        case let .room(value): CGPoint(x: value.walkableBounds.midX, y: value.walkableBounds.midY)
        case let .corridor(value): CGPoint(x: value.walkableBounds.midX, y: value.walkableBounds.midY)
        case let .wall(value): CGPoint(x: value.rotatedBounds.midX, y: value.rotatedBounds.midY)
        case let .doorway(value): CGPoint(x: value.doorwayBounds.midX, y: value.doorwayBounds.midY)
        case let .blockedArea(value): CGPoint(x: value.shape.bounds.midX, y: value.shape.bounds.midY)
        case let .object(value): CGPoint(x: value.objectBounds.midX, y: value.objectBounds.midY)
        case let .station(value): value.position.cgPoint
        case let .spawnPoint(value): value.position.cgPoint
        case let .checkpoint(value): value.position.cgPoint
        }
    }
}

extension MapGeometryConfiguration {
    var allElements: [MapGeometryElement] {
        rooms.map(MapGeometryElement.room)
            + corridors.map(MapGeometryElement.corridor)
            + walls.map(MapGeometryElement.wall)
            + doorways.map(MapGeometryElement.doorway)
            + blockedAreas.map(MapGeometryElement.blockedArea)
            + objects.map(MapGeometryElement.object)
            + stations.map(MapGeometryElement.station)
            + spawnPoints.map(MapGeometryElement.spawnPoint)
            + checkpoints.map(MapGeometryElement.checkpoint)
    }

    func element(id: MapElementID) -> MapGeometryElement? {
        allElements.first { $0.id == id }
    }

    mutating func upsert(_ element: MapGeometryElement) {
        switch element {
        case let .room(value): upsert(value, in: &rooms)
        case let .corridor(value): upsert(value, in: &corridors)
        case let .wall(value): upsert(value, in: &walls)
        case let .doorway(value): upsert(value, in: &doorways)
        case let .blockedArea(value): upsert(value, in: &blockedAreas)
        case let .object(value): upsert(value, in: &objects)
        case let .station(value): upsert(value, in: &stations)
        case let .spawnPoint(value): upsert(value, in: &spawnPoints)
        case let .checkpoint(value): upsert(value, in: &checkpoints)
        }
    }

    @discardableResult
    mutating func remove(id: MapElementID) -> Bool {
        switch id.category {
        case .room: return remove(id.rawValue, from: &rooms)
        case .corridor: return remove(id.rawValue, from: &corridors)
        case .wall: return remove(id.rawValue, from: &walls)
        case .doorway: return remove(id.rawValue, from: &doorways)
        case .blockedArea: return remove(id.rawValue, from: &blockedAreas)
        case .object: return remove(id.rawValue, from: &objects)
        case .missionStation, .foodStation: return remove(id.rawValue, from: &stations)
        case .spawnPoint: return remove(id.rawValue, from: &spawnPoints)
        case .checkpoint: return remove(id.rawValue, from: &checkpoints)
        }
    }

    private func remove<Value: Identifiable>(_ id: String, from values: inout [Value]) -> Bool where Value.ID == String {
        guard let index = values.firstIndex(where: { $0.id == id }) else { return false }
        values.remove(at: index)
        return true
    }

    private func upsert<Value: Identifiable>(_ value: Value, in values: inout [Value]) where Value.ID == String {
        if let index = values.firstIndex(where: { $0.id == value.id }) {
            values[index] = value
        } else {
            values.append(value)
        }
    }
}

enum MapEditorMode: String, CaseIterable, Identifiable, Sendable {
    case navigate
    case inspect
    case select
    case move
    case resize
    case editNodes
    case create
    case delete
    case testCollision

    var id: String { rawValue }
}

enum MapDebugSimulationMode: String, Sendable {
    case editing
    case collisionTesting
}

enum MapResizeHandle: String, CaseIterable, Identifiable, Sendable {
    case topLeft, top, topRight, left, right, bottomLeft, bottom, bottomRight
    var id: String { rawValue }
}

struct MapEditorGridConfiguration: Equatable, Sendable {
    var gridSize: CGFloat = 10
    var snapToGrid = true

    func snapped(_ value: CGFloat) -> CGFloat {
        guard snapToGrid, gridSize > 0 else { return value }
        return (value / gridSize).rounded() * gridSize
    }

    func snapped(_ point: CGPoint) -> CGPoint {
        CGPoint(x: snapped(point.x), y: snapped(point.y))
    }
}

enum MapGeometrySource: Equatable, Sendable {
    case swiftConfiguration
    case bundledJSON
    case debugDraft

    var displayName: String {
        switch self {
        case .swiftConfiguration: "SWIFT DEFAULT"
        case .bundledJSON: "BUNDLED JSON"
        case .debugDraft: "DEBUG DRAFT"
        }
    }
}
