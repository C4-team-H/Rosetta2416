import CoreGraphics
import Foundation

// MARK: - Portable geometry

struct CodablePoint: Codable, Equatable, Hashable, Sendable {
    var x: Double
    var y: Double

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    init(_ point: CGPoint) {
        x = point.x
        y = point.y
    }

    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
    var isFinite: Bool { x.isFinite && y.isFinite }
}

struct CodableSize: Codable, Equatable, Hashable, Sendable {
    var width: Double
    var height: Double

    init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    init(_ size: CGSize) {
        width = size.width
        height = size.height
    }

    var cgSize: CGSize { CGSize(width: width, height: height) }
    var isValid: Bool { width.isFinite && height.isFinite && width > 0 && height > 0 }
}

struct CodableRect: Codable, Equatable, Hashable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    init(_ rect: CGRect) {
        let rect = rect.standardized
        x = rect.minX
        y = rect.minY
        width = rect.width
        height = rect.height
    }

    var cgRect: CGRect { CGRect(x: x, y: y, width: width, height: height).standardized }
    var isValid: Bool {
        x.isFinite && y.isFinite && width.isFinite && height.isFinite && width > 0 && height > 0
    }
}

enum MapGeometryShape: Equatable, Sendable {
    case rectangle(CodableRect)
    case polygon([CodablePoint])
    case edgeChain([CodablePoint])

    var bounds: CGRect {
        switch self {
        case let .rectangle(rect):
            rect.cgRect
        case let .polygon(points), let .edgeChain(points):
            points.reduce(into: CGRect.null) { result, point in
                result = result.union(CGRect(origin: point.cgPoint, size: .zero))
            }.standardized
        }
    }
}

extension MapGeometryShape: Codable {
    private enum CodingKeys: String, CodingKey { case kind, rect, points }
    private enum Kind: String, Codable { case rectangle, polygon, edgeChain }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .rectangle:
            self = .rectangle(try container.decode(CodableRect.self, forKey: .rect))
        case .polygon:
            self = .polygon(try container.decode([CodablePoint].self, forKey: .points))
        case .edgeChain:
            self = .edgeChain(try container.decode([CodablePoint].self, forKey: .points))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .rectangle(rect):
            try container.encode(Kind.rectangle, forKey: .kind)
            try container.encode(rect, forKey: .rect)
        case let .polygon(points):
            try container.encode(Kind.polygon, forKey: .kind)
            try container.encode(points, forKey: .points)
        case let .edgeChain(points):
            try container.encode(Kind.edgeChain, forKey: .kind)
            try container.encode(points, forKey: .points)
        }
    }
}

// MARK: - Typed definitions

struct MapPlayerFootprintDefinition: Codable, Equatable, Sendable {
    var centerOffset: CodablePoint
    var radius: Double

    var runtimeValue: CollisionFootprint {
        CollisionFootprint(centerOffset: centerOffset.cgPoint, radius: radius)
    }
}

struct MapRoomDefinition: Identifiable, Codable, Equatable, Sendable {
    let id: String
    var name: String
    var roomID: RoomID?
    var frame: CodableRect
    var triggerFrame: CodableRect
    var isWalkable: Bool
    var isRequired: Bool
    /// World-space freeform outline. `nil` keeps older rectangle-only drafts valid.
    var vertices: [CodablePoint]? = nil
    /// Room-contact outline paired with `vertices`. It is edited one vertex at a time.
    var triggerVertices: [CodablePoint]? = nil

    var walkablePoints: [CGPoint] {
        validPolygonPoints(vertices) ?? rectanglePoints(frame.cgRect)
    }

    var roomTriggerPoints: [CGPoint] {
        validPolygonPoints(triggerVertices) ?? rectanglePoints(triggerFrame.cgRect)
    }

    var walkableBounds: CGRect { pointsBounds(walkablePoints) }
    var roomTriggerBounds: CGRect { pointsBounds(roomTriggerPoints) }
}

struct MapCorridorDefinition: Identifiable, Codable, Equatable, Sendable {
    let id: String
    var name: String
    var frame: CodableRect
    var isWalkable: Bool
    var isRequired: Bool
    var vertices: [CodablePoint]? = nil

    var walkablePoints: [CGPoint] {
        validPolygonPoints(vertices) ?? rectanglePoints(frame.cgRect)
    }

    var walkableBounds: CGRect { pointsBounds(walkablePoints) }
}

struct MapWallDefinition: Identifiable, Codable, Equatable, Sendable {
    let id: String
    var name: String
    var frame: CodableRect
    /// Radians around the center of `frame`. Optional keeps older debug drafts
    /// decodable; a missing value is treated as zero rotation.
    var rotation: Double? = nil
    var isEnabled: Bool
    var isRequired: Bool
    var vertices: [CodablePoint]? = nil

    var rotationRadians: Double { rotation ?? 0 }

    var rotatedCorners: [CGPoint] {
        if let points = validPolygonPoints(vertices) { return points }
        return rotatedRectangleCorners(
            frame: frame.cgRect,
            center: CGPoint(x: frame.cgRect.midX, y: frame.cgRect.midY),
            rotation: rotationRadians
        )
    }

    var rotatedBounds: CGRect {
        rotatedCorners.reduce(into: CGRect.null) { bounds, point in
            bounds = bounds.union(CGRect(origin: point, size: .zero))
        }.standardized
    }

    /// The editable center-line endpoints of the wall. Moving either endpoint
    /// changes the wall's position, length, and rotation while preserving its
    /// thickness.
    var centerlineEndpoints: [CGPoint] {
        let rect = frame.cgRect
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let localEndpoints = rect.width >= rect.height
            ? [CGPoint(x: rect.minX, y: rect.midY), CGPoint(x: rect.maxX, y: rect.midY)]
            : [CGPoint(x: rect.midX, y: rect.minY), CGPoint(x: rect.midX, y: rect.maxY)]
        return localEndpoints.map {
            rotatedPoint($0, around: center, rotation: rotationRadians)
        }
    }

    func updatingEndpoint(at index: Int, to point: CGPoint) -> MapWallDefinition {
        guard centerlineEndpoints.indices.contains(index),
              point.x.isFinite, point.y.isFinite else { return self }
        let endpoints = centerlineEndpoints
        let fixedPoint = endpoints[index == 0 ? 1 : 0]
        var movedPoint = point
        var start = index == 0 ? movedPoint : fixedPoint
        var end = index == 0 ? fixedPoint : movedPoint
        var dx = end.x - start.x
        var dy = end.y - start.y
        var length = hypot(dx, dy)
        if length < 10 {
            let originalDX = endpoints[1].x - endpoints[0].x
            let originalDY = endpoints[1].y - endpoints[0].y
            let originalLength = max(hypot(originalDX, originalDY), 0.001)
            let unitX = originalDX / originalLength
            let unitY = originalDY / originalLength
            movedPoint = index == 0
                ? CGPoint(x: fixedPoint.x - unitX * 10, y: fixedPoint.y - unitY * 10)
                : CGPoint(x: fixedPoint.x + unitX * 10, y: fixedPoint.y + unitY * 10)
            start = index == 0 ? movedPoint : fixedPoint
            end = index == 0 ? fixedPoint : movedPoint
            dx = end.x - start.x
            dy = end.y - start.y
            length = 10
        }
        let center = CGPoint(
            x: (start.x + end.x) / 2,
            y: (start.y + end.y) / 2
        )
        let thickness = max(10, min(frame.width, frame.height))
        var updated = self
        updated.frame = CodableRect(
            x: center.x - length / 2,
            y: center.y - thickness / 2,
            width: length,
            height: thickness
        )
        updated.rotation = atan2(dy, dx)
        return updated
    }

    func contains(_ point: CGPoint, tolerance: CGFloat = 0) -> Bool {
        if let points = validPolygonPoints(vertices) {
            let path = CGMutablePath()
            path.move(to: points[0])
            points.dropFirst().forEach { path.addLine(to: $0) }
            path.closeSubpath()
            return path.contains(point)
                || rotatedBounds.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        }
        return pointInRotatedRectangle(
            point,
            frame: frame.cgRect,
            center: CGPoint(x: frame.cgRect.midX, y: frame.cgRect.midY),
            rotation: rotationRadians,
            tolerance: tolerance
        )
    }
}

func rotatedRectangleCorners(
    frame: CGRect,
    center: CGPoint,
    rotation: Double
) -> [CGPoint] {
    let angle = CGFloat(rotation)
    let cosine = cos(angle)
    let sine = sin(angle)
    return [
        CGPoint(x: frame.minX, y: frame.minY),
        CGPoint(x: frame.maxX, y: frame.minY),
        CGPoint(x: frame.maxX, y: frame.maxY),
        CGPoint(x: frame.minX, y: frame.maxY)
    ].map { point in
        let dx = point.x - center.x
        let dy = point.y - center.y
        return CGPoint(
            x: center.x + dx * cosine - dy * sine,
            y: center.y + dx * sine + dy * cosine
        )
    }
}

func rotatedPoint(
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

func pointInRotatedRectangle(
    _ point: CGPoint,
    frame: CGRect,
    center: CGPoint,
    rotation: Double,
    tolerance: CGFloat = 0
) -> Bool {
    guard point.x.isFinite, point.y.isFinite, rotation.isFinite else { return false }
    let angle = -CGFloat(rotation)
    let cosine = cos(angle)
    let sine = sin(angle)
    let dx = point.x - center.x
    let dy = point.y - center.y
    let localPoint = CGPoint(
        x: center.x + dx * cosine - dy * sine,
        y: center.y + dx * sine + dy * cosine
    )
    return frame.insetBy(dx: -tolerance, dy: -tolerance).contains(localPoint)
}

struct MapDoorwayDefinition: Identifiable, Codable, Equatable, Sendable {
    let id: String
    var name: String
    var doorID: DoorID?
    var roomID: RoomID?
    var frame: CodableRect
    var defaultState: DoorState
    var isEnabled: Bool
    var isRequired: Bool
    var vertices: [CodablePoint]? = nil

    var doorwayPoints: [CGPoint] {
        validPolygonPoints(vertices) ?? rectanglePoints(frame.cgRect)
    }

    var doorwayBounds: CGRect { pointsBounds(doorwayPoints) }
}

struct MapBlockedAreaDefinition: Identifiable, Codable, Equatable, Sendable {
    let id: String
    var name: String
    var shape: MapGeometryShape
    var isEnabled: Bool
    var isRequired: Bool
}

enum MapObjectType: String, Codable, CaseIterable, Equatable, Sendable {
    case decorative
    case obstacle
    case interactive
}

struct MapObjectDefinition: Identifiable, Codable, Equatable, Sendable {
    let id: String
    var name: String
    var type: MapObjectType
    var position: CodablePoint
    var size: CodableSize
    var rotation: Double
    var interactionID: String?
    var isEnabled: Bool
    var isRequired: Bool
    /// Once present, these world-space points are authoritative over size/rotation.
    var vertices: [CodablePoint]? = nil

    var frame: CGRect {
        CGRect(
            x: position.x - size.width / 2,
            y: position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    var objectPoints: [CGPoint] {
        validPolygonPoints(vertices) ?? rotatedRectangleCorners(
            frame: frame,
            center: position.cgPoint,
            rotation: rotation
        )
    }

    var objectBounds: CGRect { pointsBounds(objectPoints) }
}

func rectanglePoints(_ frame: CGRect) -> [CGPoint] {
    [
        CGPoint(x: frame.minX, y: frame.minY),
        CGPoint(x: frame.maxX, y: frame.minY),
        CGPoint(x: frame.maxX, y: frame.maxY),
        CGPoint(x: frame.minX, y: frame.maxY)
    ]
}

func validPolygonPoints(_ points: [CodablePoint]?) -> [CGPoint]? {
    guard let points, points.count >= 3, points.allSatisfy(\.isFinite) else { return nil }
    return points.map(\.cgPoint)
}

func pointsBounds(_ points: [CGPoint]) -> CGRect {
    points.reduce(into: CGRect.null) { bounds, point in
        bounds = bounds.union(CGRect(origin: point, size: .zero))
    }.standardized
}

enum MapStationKind: String, Codable, CaseIterable, Equatable, Sendable {
    case mission
    case food
}

struct MapStationDefinition: Identifiable, Codable, Equatable, Sendable {
    let id: String
    var name: String
    var kind: MapStationKind
    var roomID: RoomID?
    var position: CodablePoint
    var interactionID: String?
    var isEnabled: Bool
    var isRequired: Bool
    /// Optional world-space editor footprint. Its bounds center remains the
    /// authoritative station position used by gameplay and interaction nodes.
    var vertices: [CodablePoint]? = nil

    var stationPoints: [CGPoint] {
        validPolygonPoints(vertices) ?? rectanglePoints(CGRect(
            x: position.x - 100,
            y: position.y - 80,
            width: 200,
            height: 160
        ))
    }

    var stationBounds: CGRect { pointsBounds(stationPoints) }
}

struct MapSpawnPointDefinition: Identifiable, Codable, Equatable, Sendable {
    let id: String
    var name: String
    var roomID: RoomID?
    var position: CodablePoint
    var isRequired: Bool
}

struct MapCheckpointDefinition: Identifiable, Codable, Equatable, Sendable {
    let id: String
    var name: String
    var checkpointID: CheckpointID?
    var roomID: RoomID?
    var position: CodablePoint
    var isRequired: Bool
}

// MARK: - Single source of truth

struct MapGeometryConfiguration: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var worldSize: CodableSize
    var playerVisualRadius: Double
    var playerFootprint: MapPlayerFootprintDefinition
    var wallThickness: Double
    var walkabilityEpsilon: Double
    var targetClampStep: Double
    var targetClampMaximumRadius: Double
    var rooms: [MapRoomDefinition]
    var corridors: [MapCorridorDefinition]
    var walls: [MapWallDefinition]
    var doorways: [MapDoorwayDefinition]
    var blockedAreas: [MapBlockedAreaDefinition]
    var objects: [MapObjectDefinition]
    var stations: [MapStationDefinition]
    var spawnPoints: [MapSpawnPointDefinition]
    var checkpoints: [MapCheckpointDefinition]
}

extension MapGeometryConfiguration {
    func spawnPoint(for roomID: RoomID) -> CGPoint? {
        spawnPoints.first(where: { $0.roomID == roomID && $0.position.isFinite })?.position.cgPoint
    }

    func checkpointPosition(for checkpointID: CheckpointID) -> CGPoint? {
        checkpoints.first(where: { $0.checkpointID == checkpointID && $0.position.isFinite })?.position.cgPoint
    }

    func safeSpawn(for checkpointID: CheckpointID) -> CGPoint {
        checkpointPosition(for: checkpointID)
            ?? spawnPoint(for: .sleepingRoom)
            ?? CGPoint(x: worldSize.width / 2, y: worldSize.height / 2)
    }

    func room(containing point: CGPoint) -> RoomID? {
        rooms.first { $0.triggerFrame.cgRect.contains(point) }?.roomID
    }
}

extension MapGeometryConfiguration {
    /// Canonical world-space Drawing Space geometry. Coordinates are committed in the
    /// 5504 x 4128 SpriteKit coordinate system (origin at bottom-left); no artwork
    /// scaling or Y-axis conversion occurs when this data is loaded at runtime.
    static var drawingSpaceDefault: MapGeometryConfiguration {
        MapGeometryConfiguration(
            schemaVersion: currentSchemaVersion,
            worldSize: CodableSize(width: 5_504, height: 4_128),
            playerVisualRadius: 57.3333,
            playerFootprint: MapPlayerFootprintDefinition(
                centerOffset: CodablePoint(x: 0, y: -11.4667),
                radius: 45.8667
            ),
            wallThickness: 61.1556,
            walkabilityEpsilon: 1.9111,
            targetClampStep: 15.2889,
            targetClampMaximumRadius: 244.6222,
            rooms: defaultRooms,
            corridors: defaultCorridors,
            walls: defaultWalls,
            doorways: defaultDoorways,
            blockedAreas: defaultBlockedAreas,
            objects: defaultObjects,
            stations: defaultStations,
            spawnPoints: defaultSpawns,
            checkpoints: defaultCheckpoints
        )
    }

    // MARK: Rooms

    private static let defaultRooms: [MapRoomDefinition] = [
        room("room-cockpit", "Cockpit", .cockpit, rect(2216.8889, 2484.4444, 1070.2222, 1204), rect(2274.2222, 2541.7778, 955.5556, 1089.3333)),
        room("room-sleeping", "Sleeping Room", .sleepingRoom, rect(668.8889, 2102.2222, 1242.2222, 955.5556), rect(726.2222, 2159.5556, 1127.5556, 840.8889)),
        room("room-kitchen", "Kitchen", .kitchen, rect(3592.8889, 2102.2222, 955.5556, 955.5556), rect(3612, 2236, 879.1111, 764.4444)),
        room("room-engine", "Engine Room", .engine, rect(2216.8889, 1051.1111, 1070.2222, 1051.1111), rect(2274.2222, 1108.4444, 955.5556, 936.4444)),
        room("room-laboratory", "Lab Room", .laboratory, rect(382.2222, 688, 1528.8889, 1414.2222), rect(439.5556, 783.5556, 1414.2222, 1261.3333)),
        room("room-storage", "Storage Room", .storage, rect(3592.8889, 688, 1452.4444, 1414.2222), rect(3650.2222, 783.5556, 1337.7778, 1261.3333))
    ]

    // MARK: Corridors

    private static let defaultCorridors: [MapCorridorDefinition] = [
        corridor("corridor-main-horizontal", "Main Horizontal", rect(1911.1111, 2102.2222, 1681.7778, 382.2222)),
        corridor("corridor-port-vertical", "Port Vertical", rect(1911.1111, 1490.6667, 305.7778, 993.7778)),
        corridor("corridor-center-vertical", "Center Vertical", rect(2599.1111, 2025.7778, 305.7778, 535.1111)),
        corridor("corridor-starboard-vertical", "Starboard Vertical", rect(3287.1111, 1490.6667, 305.7778, 993.7778))
    ]

    // MARK: Walls

    private static let defaultWalls: [MapWallDefinition] = {
        let t = 61.1556
        let segments: [(String, String, CodablePoint, CodablePoint)] = [
            ("wall-cockpit-top", "Cockpit Top", point(2216.8889, 3688.4444), point(3287.1111, 3688.4444)),
            ("wall-cockpit-left", "Cockpit Left", point(2216.8889, 3688.4444), point(2216.8889, 2484.4444)),
            ("wall-cockpit-right", "Cockpit Right", point(3287.1111, 3688.4444), point(3287.1111, 2484.4444)),
            ("wall-cockpit-bottom-left", "Cockpit Bottom Left", point(2216.8889, 2484.4444), point(2599.1111, 2484.4444)),
            ("wall-cockpit-bottom-right", "Cockpit Bottom Right", point(2904.8889, 2484.4444), point(3287.1111, 2484.4444)),
            ("wall-sleeping-top", "Sleeping Top", point(668.8889, 3057.7778), point(1911.1111, 3057.7778)),
            ("wall-sleeping-left", "Sleeping Left", point(668.8889, 3057.7778), point(668.8889, 2102.2222)),
            ("wall-sleeping-bottom", "Sleeping Bottom", point(668.8889, 2102.2222), point(1911.1111, 2102.2222)),
            ("wall-sleeping-right-upper", "Sleeping Right Upper", point(1911.1111, 3057.7778), point(1911.1111, 2522.6667)),
            ("wall-sleeping-right-lower", "Sleeping Right Lower", point(1911.1111, 2216.8889), point(1911.1111, 2102.2222)),
            ("wall-kitchen-top", "Kitchen Top", point(3592.8889, 3057.7778), point(4548.4444, 3057.7778)),
            ("wall-kitchen-right", "Kitchen Right", point(4548.4444, 3057.7778), point(4548.4444, 2102.2222)),
            ("wall-kitchen-bottom", "Kitchen Bottom", point(3592.8889, 2102.2222), point(4548.4444, 2102.2222)),
            ("wall-kitchen-left-upper", "Kitchen Left Upper", point(3592.8889, 3057.7778), point(3592.8889, 2599.1111)),
            ("wall-kitchen-left-lower", "Kitchen Left Lower", point(3592.8889, 2216.8889), point(3592.8889, 2102.2222)),
            ("wall-engine-top-left", "Engine Top Left", point(2216.8889, 2102.2222), point(2599.1111, 2102.2222)),
            ("wall-engine-top-right", "Engine Top Right", point(2904.8889, 2102.2222), point(3287.1111, 2102.2222)),
            ("wall-engine-left", "Engine Left", point(2216.8889, 2102.2222), point(2216.8889, 1051.1111)),
            ("wall-engine-right", "Engine Right", point(3287.1111, 2102.2222), point(3287.1111, 1051.1111)),
            ("wall-engine-bottom", "Engine Bottom", point(2216.8889, 1051.1111), point(3287.1111, 1051.1111)),
            ("wall-lab-top", "Lab Top", point(382.2222, 2102.2222), point(1911.1111, 2102.2222)),
            ("wall-lab-left", "Lab Left", point(382.2222, 2102.2222), point(382.2222, 688)),
            ("wall-lab-bottom", "Lab Bottom", point(382.2222, 688), point(1911.1111, 688)),
            ("wall-lab-right-upper", "Lab Right Upper", point(1911.1111, 2102.2222), point(1911.1111, 1796.4444)),
            ("wall-lab-right-lower", "Lab Right Lower", point(1911.1111, 1490.6667), point(1911.1111, 688)),
            ("wall-storage-top", "Storage Top", point(3592.8889, 2102.2222), point(5045.3333, 2102.2222)),
            ("wall-storage-right", "Storage Right", point(5045.3333, 2102.2222), point(5045.3333, 688)),
            ("wall-storage-bottom", "Storage Bottom", point(3592.8889, 688), point(5045.3333, 688)),
            ("wall-storage-left-upper", "Storage Left Upper", point(3592.8889, 2102.2222), point(3592.8889, 1796.4444)),
            ("wall-storage-left-lower", "Storage Left Lower", point(3592.8889, 1490.6667), point(3592.8889, 688))
        ]
        return segments.map { id, name, start, end in
            MapWallDefinition(id: id, name: name, frame: wallRect(start, end, thickness: t), isEnabled: true, isRequired: false)
        }
    }()

    // MARK: Doorways

    private static let defaultDoorways: [MapDoorwayDefinition] = [
        doorway("door-cockpit", "Cockpit Door", .cockpit, rect(2599.1111, 2450.0444, 305.7778, 68.8), .locked),
        doorway("door-sleeping", "Sleeping Room Door", .sleepingRoom, rect(1876.7111, 2216.8889, 68.8, 305.7778), .open),
        doorway("door-kitchen", "Kitchen Door", .kitchen, rect(3558.4889, 2216.8889, 68.8, 382.2222), .open),
        doorway("door-engine", "Engine Room Door", .engine, rect(2599.1111, 2067.8222, 305.7778, 68.8), .locked),
        doorway("door-laboratory", "Lab Room Door", .laboratory, rect(1876.7111, 1490.6667, 68.8, 305.7778), .open),
        doorway("door-storage", "Storage Room Door", .storage, rect(3558.4889, 1490.6667, 68.8, 305.7778), .locked)
    ]

    // MARK: Blocked Areas

    private static let defaultBlockedAreas: [MapBlockedAreaDefinition] = [
        MapBlockedAreaDefinition(
            id: "blocked-outer-hull",
            name: "Outer Hull",
            shape: .edgeChain([
                point(1911.1111, 3745.7778), point(3592.8889, 3745.7778),
                point(3745.7778, 3134.2222), point(4624.8889, 3076.8889),
                point(5121.7778, 2216.8889), point(5312.8889, 611.5556),
                point(191.1111, 611.5556), point(382.2222, 2216.8889),
                point(879.1111, 3076.8889), point(1758.2222, 3134.2222)
            ]),
            isEnabled: true,
            isRequired: true
        )
    ]

    // MARK: Objects

    private static let defaultObjects: [MapObjectDefinition] = [
        object("object-cockpit-main-console", "Cockpit Main Console", .obstacle, rect(2255.1111, 3218.3111, 955.5556, 183.4667)),
        object("object-cockpit-pilot-chair", "Cockpit Pilot Chair", .obstacle, rect(2675.5556, 2969.8667, 152.8889, 259.9111)),
        object("object-cockpit-navigation-display", "Cockpit Navigation Display", .obstacle, rect(2904.8889, 2599.1111, 336.3556, 573.3333)),
        object("object-cockpit-port-machinery", "Cockpit Port Machinery", .obstacle, rect(2255.1111, 2675.5556, 133.7778, 496.8889)),
        object("object-sleeping-bed", "Sleeping Bed", .obstacle, rect(1261.3333, 2694.6667, 611.5556, 305.7778)),
        object("object-sleeping-main-console", "Sleeping Main Console", .obstacle, rect(1452.4444, 2216.8889, 286.6667, 305.7778)),
        object("object-sleeping-storage", "Sleeping Storage", .obstacle, rect(764.4444, 2629.6889, 210.2222, 275.2)),
        object("object-kitchen-main-counter", "Kitchen Main Counter", .obstacle, rect(3822.2222, 2190.1333, 535.1111, 160.5333)),
        object("object-kitchen-side-counter", "Kitchen Side Counter", .obstacle, rect(4032.4444, 2408, 344, 458.6667)),
        object("object-kitchen-sink-stove", "Kitchen Sink Stove", .obstacle, rect(3822.2222, 2408, 210.2222, 172)),
        object("object-kitchen-appliance", "Kitchen Appliance", .obstacle, rect(3612, 2828.4444, 324.8889, 210.2222)),
        object("object-engine-core", "Engine Core", .obstacle, rect(2484.4444, 1184.8889, 611.5556, 649.7778)),
        object("object-engine-battery-bank", "Engine Battery Bank", .obstacle, rect(2885.7778, 1861.4222, 267.5556, 145.2444)),
        object("object-engine-port-pipes", "Engine Port Pipes", .obstacle, rect(2255.1111, 1318.6667, 145.2444, 477.7778)),
        object("object-engine-starboard-equipment", "Engine Starboard Equipment", .obstacle, rect(3172.4444, 1318.6667, 95.5556, 477.7778)),
        object("object-lab-main-table", "Lab Main Table", .obstacle, rect(993.7778, 1739.1111, 764.4444, 267.5556)),
        object("object-lab-microscope-station", "Lab Microscope Station", .obstacle, rect(477.7778, 974.6667, 458.6667, 382.2222)),
        object("object-lab-lower-bench", "Lab Lower Bench", .obstacle, rect(1089.3333, 821.7778, 802.6667, 248.4444)),
        object("object-lab-shelf", "Lab Shelf", .obstacle, rect(1662.6667, 1834.6667, 152.8889, 191.1111)),
        object("object-storage-cabinets", "Storage Cabinets", .obstacle, rect(3822.2222, 1720, 726.2222, 324.8889)),
        object("object-storage-crates", "Storage Crates", .obstacle, rect(3822.2222, 1070.2222, 420.4444, 382.2222)),
        object("object-storage-containers", "Storage Containers", .obstacle, rect(4166.2222, 821.7778, 401.3333, 401.3333)),
        object("object-storage-tool-rack", "Storage Tool Rack", .obstacle, rect(4624.8889, 821.7778, 324.8889, 554.2222)),
        object("object-storage-machinery", "Storage Machinery", .obstacle, rect(4357.3333, 1368.3556, 305.7778, 275.2))
    ]

    // MARK: Interactive and Mission Stations

    private static let defaultStations: [MapStationDefinition] = [
        station("station-lab-terminal-repair", "Lab Terminal Repair", .mission, .laboratory, point(1108.4444, 1643.5556), "lab-terminal-repair"),
        station("station-lab-memory-repair", "Lab Memory Repair", .mission, .laboratory, point(1490.6667, 1643.5556), "lab-memory-repair"),
        station("station-lab-scanner-repair", "Lab Scanner Repair", .mission, .laboratory, point(879.1111, 1223.1111), "lab-scanner-repair"),
        station("station-engine-power-connector", "Engine Power Connector", .mission, .engine, point(2369.7778, 1949.3333), "engine-power-connector"),
        station("station-engine-ignition-coil", "Engine Ignition Coil", .mission, .engine, point(2752, 1949.3333), "engine-ignition-coil"),
        station("station-engine-cooling-valve", "Engine Cooling Valve", .mission, .engine, point(3096, 1949.3333), "engine-cooling-valve"),
        station("station-engine-control-relay", "Engine Control Relay", .mission, .engine, point(3191.5556, 1872.8889), "engine-control-relay"),
        station("station-engine-reactor-link", "Engine Reactor Link", .mission, .engine, point(2369.7778, 1528.8889), "engine-reactor-link"),
        station("station-engine-pressure-feed", "Engine Pressure Feed", .mission, .engine, point(3191.5556, 1528.8889), "engine-pressure-feed"),
        station("station-engine-calibration-port", "Engine Calibration Port", .mission, .engine, point(2369.7778, 1223.1111), "engine-calibration-port"),
        station("station-engine-reactor-stabilizer", "Engine Reactor Stabilizer", .mission, .engine, point(3191.5556, 1223.1111), "engine-reactor-stabilizer"),
        station("station-engine-core-reconnect", "Engine Core Reconnect", .mission, .engine, point(2522.6667, 1127.5556), "engine-core-reconnect"),
        station("station-engine-propulsion-calibration", "Engine Propulsion Calibration", .mission, .engine, point(2752, 1127.5556), "engine-propulsion-calibration"),
        station("station-engine-cooling-restart", "Engine Cooling Restart", .mission, .engine, point(2981.3333, 1127.5556), "engine-cooling-restart"),
        station("station-engine-navigation-sync", "Engine Navigation Sync", .mission, .engine, point(3153.3333, 1127.5556), "engine-navigation-sync"),
        station("station-storage-door-controller", "Storage Door Controller", .mission, .storage, point(3745.7778, 1643.5556), "storage-door-controller"),
        station("station-storage-tool-terminal", "Storage Tool Terminal", .mission, .storage, point(4624.8889, 1643.5556), "storage-tool-terminal"),
        station("station-storage-robotic-arm", "Storage Robotic Arm", .mission, .storage, point(3707.5556, 917.3333), "storage-robotic-arm"),
        station("station-storage-calibration-unit", "Storage Calibration Unit", .mission, .storage, point(4586.6667, 821.7778), "storage-calibration-unit"),
        station("station-cockpit-navigation-control", "Cockpit Navigation Control", .mission, .cockpit, point(2369.7778, 3172.4444), "cockpit-navigation-control"),
        station("station-cockpit-communications", "Cockpit Communications", .mission, .cockpit, point(2752, 2943.1111), "cockpit-communications"),
        station("station-cockpit-flight-console", "Cockpit Flight Console", .mission, .cockpit, point(3191.5556, 3172.4444), "cockpit-flight-console"),
        station("station-kitchen-food", "Kitchen Food Station", .food, .kitchen, point(3707.5556, 2599.1111), "kitchen-food")
    ]

    // MARK: Spawn Points

    private static let defaultSpawns: [MapSpawnPointDefinition] = [
        spawn("spawn-sleeping", "Sleeping Spawn", .sleepingRoom, point(1146.6667, 2427.1111)),
        spawn("spawn-laboratory", "Lab Spawn", .laboratory, point(1643.5556, 1376)),
        spawn("spawn-engine", "Engine Spawn", .engine, point(2369.7778, 1949.3333)),
        spawn("spawn-kitchen", "Kitchen Spawn", .kitchen, point(3707.5556, 2675.5556)),
        spawn("spawn-storage", "Storage Spawn", .storage, point(3726.6667, 1490.6667)),
        spawn("spawn-cockpit", "Cockpit Spawn", .cockpit, point(2752, 2599.1111))
    ]

    // MARK: Checkpoints

    private static let defaultCheckpoints: [MapCheckpointDefinition] = [
        checkpoint(.sleepingRoom, .sleepingRoom, point(1146.6667, 2427.1111)),
        checkpoint(.laboratory, .laboratory, point(1643.5556, 1376)),
        checkpoint(.enginePhaseOne, .engine, point(2369.7778, 1949.3333)),
        checkpoint(.engineDisruption, .engine, point(2369.7778, 1949.3333)),
        checkpoint(.engineBlocked, .engine, point(2369.7778, 1949.3333)),
        checkpoint(.storage, .storage, point(3726.6667, 1490.6667)),
        checkpoint(.engineFinal, .engine, point(2369.7778, 1949.3333)),
        checkpoint(.cockpit, .cockpit, point(2752, 2599.1111))
    ]

    // MARK: Definition helpers (world-space only)

    private static func point(_ x: Double, _ y: Double) -> CodablePoint { CodablePoint(x: x, y: y) }
    private static func rect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> CodableRect {
        CodableRect(x: x, y: y, width: width, height: height)
    }

    private static func room(_ id: String, _ name: String, _ roomID: RoomID, _ frame: CodableRect, _ trigger: CodableRect) -> MapRoomDefinition {
        MapRoomDefinition(id: id, name: name, roomID: roomID, frame: frame, triggerFrame: trigger, isWalkable: true, isRequired: true)
    }

    private static func corridor(_ id: String, _ name: String, _ frame: CodableRect) -> MapCorridorDefinition {
        MapCorridorDefinition(id: id, name: name, frame: frame, isWalkable: true, isRequired: true)
    }

    private static func doorway(_ id: String, _ name: String, _ doorID: DoorID, _ frame: CodableRect, _ state: DoorState) -> MapDoorwayDefinition {
        MapDoorwayDefinition(id: id, name: name, doorID: doorID, roomID: doorID.roomID, frame: frame, defaultState: state, isEnabled: true, isRequired: true)
    }

    private static func object(_ id: String, _ name: String, _ type: MapObjectType, _ frame: CodableRect) -> MapObjectDefinition {
        let rect = frame.cgRect
        return MapObjectDefinition(
            id: id,
            name: name,
            type: type,
            position: CodablePoint(x: rect.midX, y: rect.midY),
            size: CodableSize(width: rect.width, height: rect.height),
            rotation: 0,
            interactionID: nil,
            isEnabled: true,
            isRequired: false
        )
    }

    private static func station(_ id: String, _ name: String, _ kind: MapStationKind, _ roomID: RoomID, _ position: CodablePoint, _ interactionID: String) -> MapStationDefinition {
        MapStationDefinition(id: id, name: name, kind: kind, roomID: roomID, position: position, interactionID: interactionID, isEnabled: true, isRequired: true)
    }

    private static func spawn(_ id: String, _ name: String, _ roomID: RoomID, _ position: CodablePoint) -> MapSpawnPointDefinition {
        MapSpawnPointDefinition(id: id, name: name, roomID: roomID, position: position, isRequired: true)
    }

    private static func checkpoint(_ checkpointID: CheckpointID, _ roomID: RoomID, _ position: CodablePoint) -> MapCheckpointDefinition {
        MapCheckpointDefinition(id: "checkpoint-\(checkpointID.rawValue)", name: checkpointID.rawValue, checkpointID: checkpointID, roomID: roomID, position: position, isRequired: true)
    }

    private static func wallRect(_ start: CodablePoint, _ end: CodablePoint, thickness: Double) -> CodableRect {
        let minX = min(start.x, end.x)
        let minY = min(start.y, end.y)
        let width = abs(end.x - start.x)
        let height = abs(end.y - start.y)
        return CodableRect(
            x: minX - (width == 0 ? thickness / 2 : 0),
            y: minY - (height == 0 ? thickness / 2 : 0),
            width: max(width, thickness),
            height: max(height, thickness)
        )
    }
}
