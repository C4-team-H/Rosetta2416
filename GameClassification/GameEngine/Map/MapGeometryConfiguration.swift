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
    var width: Double
    var height: Double
    var obstacleRadius: Double
    var bodyObstacleRadius: Double?

    var radius: Double {
        get { max(width, height) / 2 }
        set {
            width = newValue * 2
            height = newValue * 2
            obstacleRadius = max(obstacleRadius, newValue)
        }
    }

    init(centerOffset: CodablePoint, width: Double, height: Double, obstacleRadius: Double, bodyObstacleRadius: Double? = nil) {
        self.centerOffset = centerOffset
        self.width = width
        self.height = height
        self.obstacleRadius = obstacleRadius
        self.bodyObstacleRadius = bodyObstacleRadius
    }

    init(centerOffset: CodablePoint, radius: Double) {
        self.init(
            centerOffset: centerOffset,
            width: radius * 2,
            height: radius * 2,
            obstacleRadius: radius
        )
    }

    var runtimeValue: CollisionFootprint {
        CollisionFootprint(
            centerOffset: centerOffset.cgPoint,
            size: CGSize(width: width, height: height),
            obstacleRadius: obstacleRadius,
            bodyObstacleRadius: bodyObstacleRadius.map { CGFloat($0) }
        )
    }

    private enum CodingKeys: String, CodingKey {
        case centerOffset
        case width
        case height
        case obstacleRadius
        case bodyObstacleRadius
        case radius
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        centerOffset = try container.decode(CodablePoint.self, forKey: .centerOffset)
        if let width = try container.decodeIfPresent(Double.self, forKey: .width),
           let height = try container.decodeIfPresent(Double.self, forKey: .height) {
            self.width = width
            self.height = height
            obstacleRadius = try container.decodeIfPresent(Double.self, forKey: .obstacleRadius)
                ?? max(width, height) / 2
            bodyObstacleRadius = try container.decodeIfPresent(Double.self, forKey: .bodyObstacleRadius)
        } else {
            let radius = try container.decode(Double.self, forKey: .radius)
            width = radius * 2
            height = radius * 2
            obstacleRadius = try container.decodeIfPresent(Double.self, forKey: .obstacleRadius)
                ?? radius
            bodyObstacleRadius = try container.decodeIfPresent(Double.self, forKey: .bodyObstacleRadius)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(centerOffset, forKey: .centerOffset)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(obstacleRadius, forKey: .obstacleRadius)
        try container.encodeIfPresent(bodyObstacleRadius, forKey: .bodyObstacleRadius)
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
    /// The physical book and its map marker share this console-derived anchor.
    var albumBookPosition: CGPoint {
        guard let console = objects.first(where: { $0.id == "object-sleeping-main-console" }) else {
            return spawnPoint(for: .sleepingRoom) ?? .zero
        }
        let bounds = console.objectBounds
        return CGPoint(
            x: bounds.minX + GameMapLayout.scaled(30),
            y: bounds.minY + GameMapLayout.scaled(30)
        )
    }

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
    static var drawingSpaceDefault: MapGeometryConfiguration {
        MapGeometryConfiguration(
            schemaVersion: 1,
            worldSize: CodableSize(width: 5504, height: 4128),
            playerVisualRadius: 95.0,
//            playerVisualRadius: 114.67,
            playerFootprint: MapPlayerFootprintDefinition(
                centerOffset: CodablePoint(x: 0, y: -62.93),
                width: 91.73,
                height: 45.87,
                obstacleRadius: 45.87,
                bodyObstacleRadius: 111
            ),
            wallThickness: 61.16,
            walkabilityEpsilon: 1.91,
            targetClampStep: 15.29,
            targetClampMaximumRadius: 244.62,
            rooms: [
            MapRoomDefinition(id: "room-cockpit", name: "Cockpit", roomID: .cockpit, frame: CodableRect(x: 2180, y: 2560, width: 1150, height: 1150), triggerFrame: CodableRect(x: 2237.33, y: 2617.33, width: 1035.33, height: 1035.33), isWalkable: true, isRequired: true, vertices: [CodablePoint(x: 2180, y: 2570), CodablePoint(x: 3330, y: 2560), CodablePoint(x: 3250, y: 3630), CodablePoint(x: 2750, y: 3710), CodablePoint(x: 2260, y: 3640)], triggerVertices: [CodablePoint(x: 2237.33, y: 2627.33), CodablePoint(x: 3272.67, y: 2617.33), CodablePoint(x: 3192.67, y: 3572.67), CodablePoint(x: 2747.13, y: 3652.67), CodablePoint(x: 2317.33, y: 3582.67)]),
            MapRoomDefinition(id: "room-engine", name: "Engine Room", roomID: .engine, frame: CodableRect(x: 2210, y: 1510, width: 1090, height: 640), triggerFrame: CodableRect(x: 2267.33, y: 1567.33, width: 975.34, height: 525.34), isWalkable: true, isRequired: true, vertices: [CodablePoint(x: 2210, y: 1510), CodablePoint(x: 3300, y: 1510), CodablePoint(x: 3290, y: 2150), CodablePoint(x: 2230, y: 2150)], triggerVertices: [CodablePoint(x: 2267.33, y: 1567.33), CodablePoint(x: 3242.67, y: 1567.33), CodablePoint(x: 3232.67, y: 2092.67), CodablePoint(x: 2287.33, y: 2092.67)]),
            MapRoomDefinition(id: "room-kitchen", name: "Kitchen", roomID: .kitchen, frame: CodableRect(x: 3520, y: 2110, width: 950, height: 1390), triggerFrame: CodableRect(x: 3539.11, y: 2243.78, width: 873.56, height: 1198.89), isWalkable: true, isRequired: true, vertices: [CodablePoint(x: 3610, y: 2110), CodablePoint(x: 4470, y: 2110), CodablePoint(x: 4140, y: 2980), CodablePoint(x: 3520, y: 3500), CodablePoint(x: 3610, y: 2730)], triggerVertices: [CodablePoint(x: 3629.11, y: 2243.78), CodablePoint(x: 4412.67, y: 2243.78), CodablePoint(x: 4082.67, y: 2922.67), CodablePoint(x: 3539.11, y: 3442.67), CodablePoint(x: 3629.11, y: 2763.26)]),
            MapRoomDefinition(id: "room-laboratory", name: "Lab Room", roomID: .laboratory, frame: CodableRect(x: 330, y: 690, width: 1690, height: 1410), triggerFrame: CodableRect(x: 387.33, y: 785.56, width: 1575.34, height: 1267.11), isWalkable: true, isRequired: true, vertices: [CodablePoint(x: 330, y: 690), CodablePoint(x: 2020, y: 690), CodablePoint(x: 1950, y: 1100), CodablePoint(x: 1930, y: 1450), CodablePoint(x: 1910, y: 2100), CodablePoint(x: 910, y: 2100)], triggerVertices: [CodablePoint(x: 387.33, y: 785.56), CodablePoint(x: 1962.67, y: 785.56), CodablePoint(x: 1892.67, y: 1151.54), CodablePoint(x: 1872.67, y: 1464.01), CodablePoint(x: 1852.67, y: 2042.67), CodablePoint(x: 967.33, y: 2052.67)]),
            MapRoomDefinition(id: "room-sleeping", name: "Sleeping Room", roomID: .sleepingRoom, frame: CodableRect(x: 1030, y: 2102.22, width: 881.11, height: 937.78), triggerFrame: CodableRect(x: 1087.33, y: 2159.56, width: 766.44, height: 823.11), isWalkable: true, isRequired: true, vertices: [CodablePoint(x: 1030, y: 2110), CodablePoint(x: 1911.11, y: 2102.22), CodablePoint(x: 1910, y: 3040), CodablePoint(x: 1400, y: 3040)], triggerVertices: [CodablePoint(x: 1087.33, y: 2167.33), CodablePoint(x: 1853.78, y: 2159.56), CodablePoint(x: 1852.67, y: 2982.67), CodablePoint(x: 1457.33, y: 2982.67)]),
            MapRoomDefinition(id: "room-storage", name: "Storage Room", roomID: .storage, frame: CodableRect(x: 3500, y: 700, width: 1650, height: 1410), triggerFrame: CodableRect(x: 3557.33, y: 795.56, width: 1535.33, height: 1257.11), isWalkable: true, isRequired: true, vertices: [CodablePoint(x: 3500, y: 720), CodablePoint(x: 5150, y: 700), CodablePoint(x: 4570, y: 2110), CodablePoint(x: 3610, y: 2110), CodablePoint(x: 3600, y: 1580)], triggerVertices: [CodablePoint(x: 3557.33, y: 815.56), CodablePoint(x: 5092.67, y: 795.56), CodablePoint(x: 4512.67, y: 2052.67), CodablePoint(x: 3667.33, y: 2052.67), CodablePoint(x: 3657.33, y: 1589.45)])
            ],
            corridors: [
            MapCorridorDefinition(id: "corridor-backdoor-vertical", name: "Backdoor Vertical", frame: CodableRect(x: 2350, y: 1050, width: 140, height: 480), isWalkable: true, isRequired: false, vertices: [CodablePoint(x: 2350, y: 1050), CodablePoint(x: 2483.33, y: 1050), CodablePoint(x: 2490, y: 1530), CodablePoint(x: 2350, y: 1530)]),
            MapCorridorDefinition(id: "corridor-center-vertical", name: "Center Vertical", frame: CodableRect(x: 2670, y: 2120, width: 160, height: 470), isWalkable: true, isRequired: true, vertices: nil),
            MapCorridorDefinition(id: "corridor-main-horizontal", name: "Main Horizontal", frame: CodableRect(x: 1850, y: 2210, width: 1640, height: 230), isWalkable: true, isRequired: true, vertices: [CodablePoint(x: 1850, y: 2310), CodablePoint(x: 2010, y: 2310), CodablePoint(x: 2010, y: 2210), CodablePoint(x: 3490, y: 2210), CodablePoint(x: 3490, y: 2320), CodablePoint(x: 2120, y: 2320), CodablePoint(x: 2120, y: 2440), CodablePoint(x: 1850, y: 2440)]),
            MapCorridorDefinition(id: "corridor-port-vertical", name: "Port Vertical", frame: CodableRect(x: 1870, y: 980, width: 1590, height: 340), isWalkable: true, isRequired: true, vertices: [CodablePoint(x: 1870, y: 1180), CodablePoint(x: 2080, y: 1180), CodablePoint(x: 2080, y: 1050), CodablePoint(x: 2800, y: 1050), CodablePoint(x: 2800, y: 1100), CodablePoint(x: 3100, y: 1100), CodablePoint(x: 3100, y: 980), CodablePoint(x: 3350, y: 980), CodablePoint(x: 3350, y: 1110), CodablePoint(x: 3460, y: 1110), CodablePoint(x: 3460, y: 1200), CodablePoint(x: 3240, y: 1200), CodablePoint(x: 3230, y: 1090), CodablePoint(x: 3220, y: 1130), CodablePoint(x: 3220, y: 1210), CodablePoint(x: 2680, y: 1210), CodablePoint(x: 2680, y: 1150), CodablePoint(x: 2190, y: 1150), CodablePoint(x: 2190, y: 1320), CodablePoint(x: 1870, y: 1320)]),
            MapCorridorDefinition(id: "corridor-starboard-horizontal", name: "Starboard Horizontal", frame: CodableRect(x: 3350, y: 1660, width: 300, height: 120), isWalkable: true, isRequired: false, vertices: [CodablePoint(x: 3350, y: 1660), CodablePoint(x: 3650, y: 1660), CodablePoint(x: 3650, y: 1780), CodablePoint(x: 3350, y: 1780)]),
            MapCorridorDefinition(id: "corridor-starboard-vertical", name: "Starboard Vertical", frame: CodableRect(x: 3350, y: 1110, width: 310, height: 1470), isWalkable: true, isRequired: true, vertices: [CodablePoint(x: 3350, y: 1110), CodablePoint(x: 3460, y: 1110), CodablePoint(x: 3460, y: 2210), CodablePoint(x: 3490, y: 2210), CodablePoint(x: 3490, y: 2450), CodablePoint(x: 3660, y: 2450), CodablePoint(x: 3660, y: 2580), CodablePoint(x: 3380, y: 2580), CodablePoint(x: 3380, y: 2320), CodablePoint(x: 3350, y: 2320), CodablePoint(x: 3350, y: 2220)])
            ],
            walls: [
            MapWallDefinition(id: "wall-sleeping-right-upper-2", name: "Sleeping Right Upper 2", frame: CodableRect(x: 1930, y: 3010, width: 70, height: 530), rotation: -0.17, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-kitchen-left-bottom", name: "Kitchen Left Bottom", frame: CodableRect(x: 3560, y: 2582, width: 70, height: 460), rotation: 0.05, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-cockpit-bottom-left", name: "Cockpit Bottom Left", frame: CodableRect(x: 2156.89, y: 2533.87, width: 522.22, height: 61.16), rotation: 0, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-cockpit-bottom-right", name: "Cockpit Bottom Right", frame: CodableRect(x: 2824.89, y: 2533.87, width: 532.22, height: 61.16), rotation: 0, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-cockpit-left", name: "Cockpit Left", frame: CodableRect(x: 2192.09, y: 2533.75, width: 55.6, height: 1115.38), rotation: -0.07, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-cockpit-right", name: "Cockpit Right", frame: CodableRect(x: 3255.56, y: 2543.74, width: 59.11, height: 1108.4), rotation: 0.07, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-cockpit-top-left", name: "Cockpit Top Left", frame: CodableRect(x: 2228, y: 3640, width: 550, height: 62), rotation: 0.14, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-cockpit-top-right", name: "Cockpit Top Right", frame: CodableRect(x: 2740, y: 3647, width: 539, height: 60), rotation: -0.12, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-engine-bottom", name: "Engine Bottom", frame: CodableRect(x: 2486.89, y: 1480.53, width: 850.22, height: 51.16), rotation: 0, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-engine-bottom-backdoor", name: "Engine Bottom Backdoor", frame: CodableRect(x: 2180, y: 1480, width: 170, height: 50), rotation: 0, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-engine-left", name: "Engine Left", frame: CodableRect(x: 2203.67, y: 1481.68, width: 39.44, height: 683.98), rotation: -0.05, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-engine-right", name: "Engine Right", frame: CodableRect(x: 3259.33, y: 1480.06, width: 65.57, height: 684.21), rotation: 0, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-engine-top-left", name: "Engine Top Left", frame: CodableRect(x: 2216.89, y: 2131.64, width: 452.22, height: 31.16), rotation: 0, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-engine-top-right", name: "Engine Top Right", frame: CodableRect(x: 2834.89, y: 2131.64, width: 492.22, height: 31.16), rotation: 0, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-kitchen-bottom", name: "Kitchen Bottom", frame: CodableRect(x: 3602.89, y: 2091.64, width: 995.56, height: 61.16), rotation: 0, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 3602.89, y: 2091.64), CodablePoint(x: 4598.44, y: 2091.64), CodablePoint(x: 4598.44, y: 2152.8), CodablePoint(x: 4266.67, y: 2150), CodablePoint(x: 3602.89, y: 2152.8)]),
            MapWallDefinition(id: "wall-kitchen-left-lower", name: "Kitchen Left Lower", frame: CodableRect(x: 3582.31, y: 2102.22, width: 71.16, height: 335), rotation: 0, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-kitchen-left-upper", name: "Kitchen Left Upper", frame: CodableRect(x: 3510.72, y: 2982.28, width: 72.34, height: 559.22), rotation: 0.15, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-kitchen-right", name: "Kitchen Right", frame: CodableRect(x: 4275.09, y: 2093.66, width: 66.7, height: 902.68), rotation: 0.37, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-kitchen-top", name: "Kitchen Top", frame: CodableRect(x: 3792.61, y: 2772.03, width: 66.12, height: 921.5), rotation: -2.25, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-lab-bottom", name: "Lab Bottom", frame: CodableRect(x: 382.22, y: 687.42, width: 1658.89, height: 61.16), rotation: 0, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-lab-left", name: "Lab Left", frame: CodableRect(x: 621.64, y: 638, width: 61.16, height: 1534.22), rotation: -0.38, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-lab-right-lower", name: "Lab Right Lower", frame: CodableRect(x: 1941.53, y: 688, width: 61.16, height: 490), rotation: 0.16, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-lab-right-upper", name: "Lab Right Upper", frame: CodableRect(x: 1867.31, y: 1328.64, width: 66.6, height: 825.93), rotation: 0.05, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-lab-top", name: "Lab Top", frame: CodableRect(x: 902.22, y: 2081.64, width: 998.89, height: 71.16), rotation: 0, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-sleeping-bottom", name: "Sleeping Bottom", frame: CodableRect(x: 898.89, y: 2081.64, width: 1002.22, height: 71.16), rotation: 0, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-sleeping-left", name: "Sleeping Left", frame: CodableRect(x: 1188.31, y: 2102.22, width: 61.16, height: 955.56), rotation: -0.38, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-sleeping-right-lower", name: "Sleeping Right Lower", frame: CodableRect(x: 1850.53, y: 2102.22, width: 61.16, height: 204.67), rotation: 0, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-sleeping-right-upper", name: "Sleeping Right Upper", frame: CodableRect(x: 1873.63, y: 2441.9, width: 70.97, height: 605.98), rotation: -0.05, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-sleeping-top", name: "Sleeping Top", frame: CodableRect(x: 1238.89, y: 3219.42, width: 912.22, height: 61.16), rotation: 0.7, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-storage-bottom", name: "Storage Bottom", frame: CodableRect(x: 3492.89, y: 687.42, width: 1682.44, height: 61.16), rotation: 0, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-storage-left-lower", name: "Storage Left Lower", frame: CodableRect(x: 3454.19, y: 675.02, width: 195.81, height: 984.98), rotation: -0.12, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 3454.19, y: 684.7), CodablePoint(x: 3536.16, y: 675.02), CodablePoint(x: 3650, y: 1660), CodablePoint(x: 3560, y: 1660)]),
            MapWallDefinition(id: "wall-storage-left-upper", name: "Storage Left Upper", frame: CodableRect(x: 3572.32, y: 1785.96, width: 81.14, height: 368.26), rotation: -0.03, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-storage-right", name: "Storage Right", frame: CodableRect(x: 4824.76, y: 638, width: 61.16, height: 1564.22), rotation: 0.38, isEnabled: true, isRequired: false, vertices: nil),
            MapWallDefinition(id: "wall-storage-top", name: "Storage Top", frame: CodableRect(x: 3592.89, y: 2091.64, width: 1002.44, height: 61.16), rotation: 0, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 3592.89, y: 2091.64), CodablePoint(x: 4595.33, y: 2091.64), CodablePoint(x: 4595.33, y: 2152.8), CodablePoint(x: 4032.61, y: 2150), CodablePoint(x: 3592.89, y: 2152.8)])
            ],
            doorways: [
            MapDoorwayDefinition(id: "door-cockpit", name: "Cockpit Door", doorID: .cockpit, roomID: .cockpit, frame: CodableRect(x: 2679.11, y: 2535.04, width: 145.78, height: 58.8), defaultState: .locked, isEnabled: true, isRequired: true, vertices: nil),
            MapDoorwayDefinition(id: "door-engine", name: "Engine Room Door", doorID: .engine, roomID: .engine, frame: CodableRect(x: 2671.11, y: 2127.82, width: 159.78, height: 38.8), defaultState: .locked, isEnabled: true, isRequired: true, vertices: nil),
            MapDoorwayDefinition(id: "door-kitchen", name: "Kitchen Door", doorID: .kitchen, roomID: .kitchen, frame: CodableRect(x: 3572, y: 2436.89, width: 80, height: 142.22), defaultState: .open, isEnabled: true, isRequired: true, vertices: nil),
            MapDoorwayDefinition(id: "door-laboratory", name: "Lab Room Door", doorID: .laboratory, roomID: .laboratory, frame: CodableRect(x: 1886.71, y: 1180.67, width: 68.8, height: 145.78), defaultState: .open, isEnabled: true, isRequired: true, vertices: nil),
            MapDoorwayDefinition(id: "door-sleeping", name: "Sleeping Room Door", doorID: .sleepingRoom, roomID: .sleepingRoom, frame: CodableRect(x: 1853.71, y: 2316.89, width: 61.8, height: 115.78), defaultState: .open, isEnabled: true, isRequired: true, vertices: nil),
            MapDoorwayDefinition(id: "door-storage", name: "Storage Room Door", doorID: .storage, roomID: .storage, frame: CodableRect(x: 3576.49, y: 1665.67, width: 65.8, height: 112.78), defaultState: .locked, isEnabled: true, isRequired: true, vertices: nil),
            MapDoorwayDefinition(id: "door-engine-back", name: "Engine Room Back Door", doorID: .engineBackDoor, roomID: .engine, frame: CodableRect(x: 2350, y: 1481, width: 130, height: 50), defaultState: .locked, isEnabled: true, isRequired: true, vertices: nil)
            ],
            blockedAreas: [
            MapBlockedAreaDefinition(id: "blocked-outer-hull", name: "Front Door Engine Blocked Area", shape: .edgeChain([CodablePoint(x: 2047.61, y: 3556.07), CodablePoint(x: 2747.61, y: 3716.07), CodablePoint(x: 3457.61, y: 3556.07), CodablePoint(x: 4115.46, y: 2985.91), CodablePoint(x: 4480, y: 2130), CodablePoint(x: 4570, y: 2130), CodablePoint(x: 5150, y: 710), CodablePoint(x: 360, y: 700), CodablePoint(x: 937.61, y: 2126.07), CodablePoint(x: 1027.61, y: 2126.07), CodablePoint(x: 1371.69, y: 2980.36), CodablePoint(x: 2067.61, y: 3566.07)]), isEnabled: true, isRequired: true)
            ],
            objects: [
            MapObjectDefinition(id: "object-lab-room-chair", name: "Lab Room Chair", type: .obstacle, position: CodablePoint(x: 1485, y: 1630), size: CodableSize(width: 110, height: 160), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 1480, y: 1590), CodablePoint(x: 1450, y: 1560), CodablePoint(x: 1490, y: 1550), CodablePoint(x: 1530, y: 1570), CodablePoint(x: 1500, y: 1590), CodablePoint(x: 1500, y: 1620), CodablePoint(x: 1540, y: 1640), CodablePoint(x: 1540, y: 1680), CodablePoint(x: 1490, y: 1710), CodablePoint(x: 1430, y: 1690), CodablePoint(x: 1430, y: 1640), CodablePoint(x: 1480, y: 1620)]),
            MapObjectDefinition(id: "object-side-wall-sleeping-room", name: "Side Wall Sleeping Room", type: .obstacle, position: CodablePoint(x: 1250.64, y: 2555), size: CodableSize(width: 361.28, height: 810), rotation: -0.35, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 1070, y: 2150), CodablePoint(x: 1160, y: 2150), CodablePoint(x: 1431.28, y: 2914.51), CodablePoint(x: 1400, y: 2960)]),
            MapObjectDefinition(id: "object-front-wall-storage-room", name: "Front Wall Storage Room", type: .obstacle, position: CodablePoint(x: 4095, y: 1955), size: CodableSize(width: 870, height: 270), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: nil),
            MapObjectDefinition(id: "object-right-side-wall-storage-room", name: "Right Side Wall Storage Room", type: .obstacle, position: CodablePoint(x: 4800, y: 1430), size: CodableSize(width: 580, height: 1360), rotation: 0.35, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 4930, y: 750), CodablePoint(x: 5090, y: 750), CodablePoint(x: 4530, y: 2110), CodablePoint(x: 4510, y: 1890)]),
            MapObjectDefinition(id: "object-left-side-wall-storage-room", name: "Left Side Wall Storage Room", type: .obstacle, position: CodablePoint(x: 3600, y: 1215), size: CodableSize(width: 100, height: 910), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 3550, y: 760), CodablePoint(x: 3600, y: 760), CodablePoint(x: 3650, y: 1550), CodablePoint(x: 3650, y: 1670)]),
            MapObjectDefinition(id: "object-upper-left-wall-kitchen-room", name: "Upper Left Wall Kitchen Room", type: .obstacle, position: CodablePoint(x: 3835, y: 3141), size: CodableSize(width: 570, height: 680), rotation: -0.7, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 3590, y: 3241), CodablePoint(x: 4120, y: 2801), CodablePoint(x: 4120, y: 2951), CodablePoint(x: 3550, y: 3481)]),
            MapObjectDefinition(id: "object-side-wall-kitchen", name: "Side Wall Kitchen", type: .obstacle, position: CodablePoint(x: 4265, y: 2545), size: CodableSize(width: 310, height: 790), rotation: 0.35, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 4350, y: 2150), CodablePoint(x: 4420, y: 2150), CodablePoint(x: 4120, y: 2940), CodablePoint(x: 4110, y: 2800)]),
            MapObjectDefinition(id: "object-kitchen-chair", name: "Kitchen Chair", type: .obstacle, position: CodablePoint(x: 3925, y: 2575), size: CodableSize(width: 110, height: 150), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 3900, y: 2510), CodablePoint(x: 3920, y: 2500), CodablePoint(x: 3950, y: 2500), CodablePoint(x: 3970, y: 2510), CodablePoint(x: 3970, y: 2530), CodablePoint(x: 3950, y: 2540), CodablePoint(x: 3940, y: 2570), CodablePoint(x: 3980, y: 2590), CodablePoint(x: 3980, y: 2640), CodablePoint(x: 3940, y: 2650), CodablePoint(x: 3900, y: 2650), CodablePoint(x: 3870, y: 2640), CodablePoint(x: 3870, y: 2590), CodablePoint(x: 3920, y: 2570), CodablePoint(x: 3920, y: 2530), CodablePoint(x: 3910, y: 2530)]),
            MapObjectDefinition(id: "object-lab-room-front-wall", name: "Lab Room Front Wall", type: .obstacle, position: CodablePoint(x: 1415, y: 1960), size: CodableSize(width: 870, height: 260), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: nil),
            MapObjectDefinition(id: "object-side-wall-lab-room", name: "Side Wall Lab Room", type: .obstacle, position: CodablePoint(x: 705, y: 1420), size: CodableSize(width: 550, height: 1340), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 430, y: 750), CodablePoint(x: 580, y: 750), CodablePoint(x: 980, y: 1820), CodablePoint(x: 980, y: 2090)]),
            MapObjectDefinition(id: "object-engine-pipe", name: "Engine Pipe", type: .obstacle, position: CodablePoint(x: 2910, y: 1975), size: CodableSize(width: 60, height: 190), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 2940, y: 1880), CodablePoint(x: 2930, y: 2030), CodablePoint(x: 2930, y: 2050), CodablePoint(x: 2910, y: 2070), CodablePoint(x: 2890, y: 2050), CodablePoint(x: 2880, y: 2010), CodablePoint(x: 2900, y: 1990), CodablePoint(x: 2900, y: 1880)]),
            MapObjectDefinition(id: "object-front-right-wall-engine-room", name: "Front Right Wall Engine Room", type: .obstacle, position: CodablePoint(x: 3050, y: 2045), size: CodableSize(width: 420, height: 170), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: nil),
            MapObjectDefinition(id: "object-front-left-wall-engine-room", name: "Front Left Wall Engine Room", type: .obstacle, position: CodablePoint(x: 2470, y: 2035), size: CodableSize(width: 400, height: 170), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: nil),
            MapObjectDefinition(id: "object-left-bottom-wall-lab-room", name: "Left Bottom Wall Lab Room", type: .obstacle, position: CodablePoint(x: 1920, y: 965), size: CodableSize(width: 100, height: 430), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 1880, y: 750), CodablePoint(x: 1970, y: 750), CodablePoint(x: 1910, y: 1180), CodablePoint(x: 1870, y: 1170)]),
            MapObjectDefinition(id: "object-wall-engine-side-front", name: "Wall Engine Side Front", type: .obstacle, position: CodablePoint(x: 2255, y: 1830), size: CodableSize(width: 50, height: 600), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 2230, y: 1530), CodablePoint(x: 2270, y: 1530), CodablePoint(x: 2280, y: 1950), CodablePoint(x: 2260, y: 2130)]),
            MapObjectDefinition(id: "object-wall-engine-side-right", name: "Wall Engine Side Right", type: .obstacle, position: CodablePoint(x: 3240, y: 1820), size: CodableSize(width: 40, height: 600), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 3230, y: 1520), CodablePoint(x: 3260, y: 1530), CodablePoint(x: 3260, y: 2120), CodablePoint(x: 3220, y: 1970)]),
            MapObjectDefinition(id: "object-cockpit-main-console", name: "Cockpit Main Console", type: .obstacle, position: CodablePoint(x: 2755, y: 3275), size: CodableSize(width: 990, height: 190), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 2260, y: 3180), CodablePoint(x: 3250, y: 3180), CodablePoint(x: 3240, y: 3370), CodablePoint(x: 2270, y: 3370)]),
            MapObjectDefinition(id: "object-cockpit-pilot-chair", name: "Cockpit Pilot Chair", type: .obstacle, position: CodablePoint(x: 2750, y: 3214.89), size: CodableSize(width: 160, height: 309.78), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 2670, y: 3170), CodablePoint(x: 2700, y: 3140), CodablePoint(x: 2740, y: 3120), CodablePoint(x: 2740, y: 3090), CodablePoint(x: 2710, y: 3070), CodablePoint(x: 2750, y: 3060), CodablePoint(x: 2790, y: 3070), CodablePoint(x: 2760, y: 3090), CodablePoint(x: 2760, y: 3120), CodablePoint(x: 2810, y: 3140), CodablePoint(x: 2830, y: 3180), CodablePoint(x: 2828.45, y: 3369.78), CodablePoint(x: 2675.56, y: 3369.78)]),
            MapObjectDefinition(id: "object-cockpit-port-machinery", name: "Cockpit Port Machinery", type: .obstacle, position: CodablePoint(x: 2330, y: 2855), size: CodableSize(width: 140, height: 370), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 2260, y: 2760), CodablePoint(x: 2260, y: 2670), CodablePoint(x: 2390, y: 2670), CodablePoint(x: 2400, y: 2970), CodablePoint(x: 2310, y: 3040), CodablePoint(x: 2280, y: 3030)]),
            MapObjectDefinition(id: "object-engine-battery-bank", name: "Engine Battery Bank", type: .obstacle, position: CodablePoint(x: 3101.67, y: 1985), size: CodableSize(width: 303.34, height: 190), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 3000, y: 1910), CodablePoint(x: 3120, y: 1890), CodablePoint(x: 3190, y: 1890), CodablePoint(x: 3253.34, y: 1911.42), CodablePoint(x: 3250, y: 2080), CodablePoint(x: 2990, y: 2080), CodablePoint(x: 2960, y: 2040), CodablePoint(x: 2980, y: 2010), CodablePoint(x: 2950, y: 1980)]),
            MapObjectDefinition(id: "object-engine-core", name: "Engine Core", type: .obstacle, position: CodablePoint(x: 2895, y: 1655), size: CodableSize(width: 730, height: 250), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 2530, y: 1530), CodablePoint(x: 3260, y: 1540.95), CodablePoint(x: 3260, y: 1760), CodablePoint(x: 3210, y: 1780), CodablePoint(x: 3150, y: 1780), CodablePoint(x: 3110, y: 1760), CodablePoint(x: 2530, y: 1749.05)]),
            MapObjectDefinition(id: "object-engine-starboard-equipment", name: "Engine Starboard Equipment", type: .obstacle, position: CodablePoint(x: 2460, y: 1988.22), size: CodableSize(width: 300, height: 176.44), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 2310, y: 1950), CodablePoint(x: 2320, y: 1900), CodablePoint(x: 2590, y: 1900), CodablePoint(x: 2610, y: 1920), CodablePoint(x: 2610, y: 2050), CodablePoint(x: 2560, y: 2070), CodablePoint(x: 2312.44, y: 2076.44)]),
            MapObjectDefinition(id: "object-kitchen-appliance", name: "Kitchen Appliance", type: .obstacle, position: CodablePoint(x: 3805, y: 2980), size: CodableSize(width: 290, height: 180), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 3680, y: 2890), CodablePoint(x: 3940, y: 2890), CodablePoint(x: 3950, y: 2920), CodablePoint(x: 3950, y: 3040), CodablePoint(x: 3940, y: 3070), CodablePoint(x: 3680, y: 3070), CodablePoint(x: 3660, y: 2990)]),
            MapObjectDefinition(id: "object-kitchen-cabinet", name: "Kitchen Cabinet", type: .obstacle, position: CodablePoint(x: 4265, y: 2315), size: CodableSize(width: 130, height: 230), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 4240, y: 2200), CodablePoint(x: 4310, y: 2200), CodablePoint(x: 4330, y: 2310), CodablePoint(x: 4290, y: 2430), CodablePoint(x: 4220, y: 2430), CodablePoint(x: 4200, y: 2310)]),
            MapObjectDefinition(id: "object-kitchen-main-counter", name: "Kitchen Main Counter", type: .obstacle, position: CodablePoint(x: 3970, y: 2225), size: CodableSize(width: 520, height: 130), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 3730, y: 2160), CodablePoint(x: 4230, y: 2160), CodablePoint(x: 4180, y: 2290), CodablePoint(x: 3720, y: 2290), CodablePoint(x: 3710, y: 2220)]),
            MapObjectDefinition(id: "object-kitchen-side-counter", name: "Kitchen Side Counter", type: .obstacle, position: CodablePoint(x: 4115, y: 2625), size: CodableSize(width: 250, height: 330), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 4050, y: 2460), CodablePoint(x: 4240, y: 2460), CodablePoint(x: 4240, y: 2510), CodablePoint(x: 4140, y: 2790), CodablePoint(x: 3990, y: 2790), CodablePoint(x: 3990, y: 2750)]),
            MapObjectDefinition(id: "object-lab-lower-bench", name: "Lab Lower Bench", type: .obstacle, position: CodablePoint(x: 1470, y: 925), size: CodableSize(width: 820, height: 330), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 1060, y: 760), CodablePoint(x: 1880, y: 760), CodablePoint(x: 1880, y: 1090), CodablePoint(x: 1160, y: 1090), CodablePoint(x: 1130, y: 1000), CodablePoint(x: 1130, y: 870), CodablePoint(x: 1080, y: 860)]),
            MapObjectDefinition(id: "object-lab-main-table", name: "Lab Main Table", type: .obstacle, position: CodablePoint(x: 1605, y: 1820), size: CodableSize(width: 450, height: 140), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 1380, y: 1750), CodablePoint(x: 1830, y: 1750), CodablePoint(x: 1790, y: 1890), CodablePoint(x: 1430, y: 1890)]),
            MapObjectDefinition(id: "object-lab-microscope-station", name: "Lab Microscope Station", type: .obstacle, position: CodablePoint(x: 780, y: 985), size: CodableSize(width: 500, height: 430), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 530, y: 770), CodablePoint(x: 920, y: 770), CodablePoint(x: 1030, y: 1120), CodablePoint(x: 1020, y: 1190), CodablePoint(x: 700, y: 1200)]),
            MapObjectDefinition(id: "object-lab-monitor-1", name: "Lab Monitor 1", type: .obstacle, position: CodablePoint(x: 1775, y: 1535), size: CodableSize(width: 150, height: 370), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 1710, y: 1350), CodablePoint(x: 1850, y: 1360), CodablePoint(x: 1830, y: 1700), CodablePoint(x: 1820, y: 1720), CodablePoint(x: 1700, y: 1640)]),
            MapObjectDefinition(id: "object-lab-monitor-2", name: "Lab Monitor 2", type: .obstacle, position: CodablePoint(x: 1157.5, y: 1792.5), size: CodableSize(width: 305, height: 165), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 1010, y: 1710), CodablePoint(x: 1260, y: 1710), CodablePoint(x: 1310, y: 1800), CodablePoint(x: 1275, y: 1875), CodablePoint(x: 1005, y: 1875)]),
            MapObjectDefinition(id: "object-sleeping-bed", name: "Sleeping Bed", type: .obstacle, position: CodablePoint(x: 1620, y: 2825), size: CodableSize(width: 500, height: 250), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 1390, y: 2700), CodablePoint(x: 1850, y: 2700), CodablePoint(x: 1870, y: 2950), CodablePoint(x: 1430, y: 2950), CodablePoint(x: 1380, y: 2880), CodablePoint(x: 1370, y: 2790)]),
            MapObjectDefinition(id: "object-sleeping-main-console", name: "Sleeping Main Console", type: .obstacle, position: CodablePoint(x: 1310, y: 2335), size: CodableSize(width: 340, height: 350), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 1140, y: 2180), CodablePoint(x: 1390, y: 2160), CodablePoint(x: 1480, y: 2480), CodablePoint(x: 1460, y: 2510), CodablePoint(x: 1270, y: 2510)]),
            MapObjectDefinition(id: "object-storage-barrel-1", name: "Storage Barrel 1", type: .obstacle, position: CodablePoint(x: 4285, y: 1270), size: CodableSize(width: 190, height: 340), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 4200, y: 1130), CodablePoint(x: 4300, y: 1100), CodablePoint(x: 4380, y: 1130), CodablePoint(x: 4380, y: 1420), CodablePoint(x: 4330, y: 1440), CodablePoint(x: 4230, y: 1440), CodablePoint(x: 4190, y: 1390)]),
            MapObjectDefinition(id: "object-storage-cabinets", name: "Storage Cabinets", type: .obstacle, position: CodablePoint(x: 4195, y: 1850), size: CodableSize(width: 730, height: 380), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 3830, y: 1790), CodablePoint(x: 3870, y: 1660), CodablePoint(x: 4550, y: 1660), CodablePoint(x: 4560, y: 1930), CodablePoint(x: 4510, y: 2040), CodablePoint(x: 3840, y: 2030)]),
            MapObjectDefinition(id: "object-storage-containers", name: "Storage Containers", type: .obstacle, position: CodablePoint(x: 4225, y: 1010), size: CodableSize(width: 330, height: 180), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 4080, y: 930), CodablePoint(x: 4370, y: 920), CodablePoint(x: 4390, y: 1010), CodablePoint(x: 4350, y: 1100), CodablePoint(x: 4090, y: 1090), CodablePoint(x: 4060, y: 1000)]),
            MapObjectDefinition(id: "object-storage-crates", name: "Storage Crates", type: .obstacle, position: CodablePoint(x: 4090, y: 1245), size: CodableSize(width: 320, height: 390), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 3930, y: 1250), CodablePoint(x: 4000, y: 1050), CodablePoint(x: 4210, y: 1060), CodablePoint(x: 4250, y: 1240), CodablePoint(x: 4160, y: 1440), CodablePoint(x: 3930, y: 1420)]),
            MapObjectDefinition(id: "object-storage-machinery", name: "Storage Machinery", type: .obstacle, position: CodablePoint(x: 4600, y: 1515), size: CodableSize(width: 200, height: 370), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 4580, y: 1330), CodablePoint(x: 4700, y: 1360), CodablePoint(x: 4680, y: 1430), CodablePoint(x: 4600, y: 1700), CodablePoint(x: 4500, y: 1600)]),
            MapObjectDefinition(id: "object-storage-monitor", name: "Storagen Monitor", type: .obstacle, position: CodablePoint(x: 3700, y: 980), size: CodableSize(width: 140, height: 360), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 3630, y: 870), CodablePoint(x: 3630, y: 800), CodablePoint(x: 3760, y: 800), CodablePoint(x: 3770, y: 1070), CodablePoint(x: 3670, y: 1160), CodablePoint(x: 3650, y: 1150)]),
            MapObjectDefinition(id: "object-storage-tool-rack", name: "Storage Tool Rack", type: .obstacle, position: CodablePoint(x: 4720, y: 950), size: CodableSize(width: 400, height: 400), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false, vertices: [CodablePoint(x: 4560, y: 750), CodablePoint(x: 4920, y: 750), CodablePoint(x: 4770, y: 1150), CodablePoint(x: 4550, y: 1140), CodablePoint(x: 4520, y: 960)])
            ],
            stations: [
            MapStationDefinition(id: "station-cockpit-communications", name: "Cockpit Communications", kind: .mission, roomID: .cockpit, position: CodablePoint(x: 3082, y: 3293.11), interactionID: "cockpit-communications", isEnabled: true, isRequired: true, vertices: nil),
            MapStationDefinition(id: "station-cockpit-flight-console", name: "Cockpit Flight Console", kind: .mission, roomID: .cockpit, position: CodablePoint(x: 2331.56, y: 2852.44), interactionID: "cockpit-flight-console", isEnabled: true, isRequired: true, vertices: nil),
            MapStationDefinition(id: "station-cockpit-navigation-control", name: "Cockpit Navigation Control", kind: .mission, roomID: .cockpit, position: CodablePoint(x: 2749.78, y: 3281.44), interactionID: "cockpit-navigation-control", isEnabled: true, isRequired: true, vertices: nil),
            MapStationDefinition(id: "station-engine-calibration-port", name: "Engine Calibration Port", kind: .mission, roomID: .engine, position: CodablePoint(x: 2679.78, y: 1663.11), interactionID: "engine-calibration-port", isEnabled: true, isRequired: true, vertices: nil),
            MapStationDefinition(id: "station-engine-control-relay", name: "Engine Control Relay", kind: .mission, roomID: .engine, position: CodablePoint(x: 3151.56, y: 1982.89), interactionID: "engine-control-relay", isEnabled: true, isRequired: true, vertices: nil),
            MapStationDefinition(id: "station-engine-cooling-restart", name: "Engine Cooling Restart", kind: .mission, roomID: .engine, position: CodablePoint(x: 3021.33, y: 1667.56), interactionID: "engine-cooling-restart", isEnabled: true, isRequired: true, vertices: nil),
            MapStationDefinition(id: "station-engine-cooling-valve", name: "Engine Cooling Valve", kind: .mission, roomID: .engine, position: CodablePoint(x: 3066, y: 1989.33), interactionID: "engine-cooling-valve", isEnabled: true, isRequired: true, vertices: nil),
            MapStationDefinition(id: "station-engine-core-reconnect", name: "Engine Core Reconnect", kind: .mission, roomID: .engine, position: CodablePoint(x: 2882.67, y: 1667.56), interactionID: "engine-core-reconnect", isEnabled: true, isRequired: true, vertices: nil),
            MapStationDefinition(id: "station-engine-ignition-coil", name: "Engine Ignition Coil", kind: .mission, roomID: .engine, position: CodablePoint(x: 2512, y: 1989.33), interactionID: "engine-ignition-coil", isEnabled: true, isRequired: true, vertices: nil),
            MapStationDefinition(id: "station-engine-navigation-sync", name: "Engine Navigation Sync", kind: .mission, roomID: .engine, position: CodablePoint(x: 3023.33, y: 1667.56), interactionID: "engine-navigation-sync", isEnabled: true, isRequired: true, vertices: nil),
            MapStationDefinition(id: "station-engine-power-connector", name: "Engine Power Connector", kind: .mission, roomID: .engine, position: CodablePoint(x: 2369.78, y: 1989.33), interactionID: "engine-power-connector", isEnabled: true, isRequired: true, vertices: nil),
            MapStationDefinition(id: "station-engine-pressure-feed", name: "Engine Pressure Feed", kind: .mission, roomID: .engine, position: CodablePoint(x: 3191.56, y: 1668.89), interactionID: "engine-pressure-feed", isEnabled: true, isRequired: true, vertices: nil),
            MapStationDefinition(id: "station-engine-propulsion-calibration", name: "Engine Propulsion Calibration", kind: .mission, roomID: .engine, position: CodablePoint(x: 2882, y: 1667.56), interactionID: "engine-propulsion-calibration", isEnabled: true, isRequired: true, vertices: nil),
            MapStationDefinition(id: "station-engine-reactor-link", name: "Engine Reactor Link", kind: .mission, roomID: .engine, position: CodablePoint(x: 2439.78, y: 1991.89), interactionID: "engine-reactor-link", isEnabled: true, isRequired: true, vertices: nil),
            MapStationDefinition(id: "station-engine-reactor-stabilizer", name: "Engine Reactor Stabilizer", kind: .mission, roomID: .engine, position: CodablePoint(x: 3191.56, y: 1663.11), interactionID: "engine-reactor-stabilizer", isEnabled: true, isRequired: true, vertices: nil),
            MapStationDefinition(id: "station-kitchen-food", name: "Kitchen Food Station", kind: .food, roomID: .kitchen, position: CodablePoint(x: 4107.56, y: 2569.11), interactionID: "kitchen-food", isEnabled: true, isRequired: true, vertices: nil),
            MapStationDefinition(id: "station-lab-memory-repair", name: "Lab Memory Repair", kind: .mission, roomID: .laboratory, position: CodablePoint(x: 1770.67, y: 1513.56), interactionID: "lab-memory-repair", isEnabled: true, isRequired: true, vertices: nil),
            MapStationDefinition(id: "station-lab-scanner-repair", name: "Lab Scanner Repair", kind: .mission, roomID: .laboratory, position: CodablePoint(x: 1539.11, y: 1843.11), interactionID: "lab-scanner-repair", isEnabled: true, isRequired: true, vertices: nil),
            MapStationDefinition(id: "station-lab-terminal-repair", name: "Lab Terminal Repair", kind: .mission, roomID: .laboratory, position: CodablePoint(x: 1138.44, y: 1793.56), interactionID: "lab-terminal-repair", isEnabled: true, isRequired: true, vertices: nil),
            MapStationDefinition(id: "station-storage-calibration-unit", name: "Storage Calibration Unit", kind: .mission, roomID: .storage, position: CodablePoint(x: 4046.67, y: 1741.78), interactionID: "storage-calibration-unit", isEnabled: true, isRequired: true, vertices: nil),
            MapStationDefinition(id: "station-storage-door-controller", name: "Storage Door Controller", kind: .mission, roomID: .storage, position: CodablePoint(x: 3705.78, y: 1023.56), interactionID: "storage-door-controller", isEnabled: true, isRequired: true, vertices: nil),
            MapStationDefinition(id: "station-storage-robotic-arm", name: "Storage Robotic Arm", kind: .mission, roomID: .storage, position: CodablePoint(x: 3707.56, y: 917.33), interactionID: "storage-robotic-arm", isEnabled: true, isRequired: true, vertices: nil),
            MapStationDefinition(id: "station-storage-tool-terminal", name: "Storage Tool Terminal", kind: .mission, roomID: .storage, position: CodablePoint(x: 4604.89, y: 1493.56), interactionID: "storage-tool-terminal", isEnabled: true, isRequired: true, vertices: nil)
            ],
            spawnPoints: [
            MapSpawnPointDefinition(id: "spawn-cockpit", name: "Cockpit Spawn", roomID: .cockpit, position: CodablePoint(x: 2752, y: 2919.11), isRequired: true),
            MapSpawnPointDefinition(id: "spawn-engine", name: "Engine Spawn", roomID: .engine, position: CodablePoint(x: 2369.78, y: 1749.33), isRequired: true),
            MapSpawnPointDefinition(id: "spawn-kitchen", name: "Kitchen Spawn", roomID: .kitchen, position: CodablePoint(x: 3847.56, y: 2765.56), isRequired: true),
            MapSpawnPointDefinition(id: "spawn-laboratory", name: "Lab Spawn", roomID: .laboratory, position: CodablePoint(x: 1283.56, y: 1376), isRequired: true),
            MapSpawnPointDefinition(id: "spawn-sleeping", name: "Sleeping Spawn", roomID: .sleepingRoom, position: CodablePoint(x: 1656.67, y: 2427.11), isRequired: true),
            MapSpawnPointDefinition(id: "spawn-storage", name: "Storage Spawn", roomID: .storage, position: CodablePoint(x: 3760, y: 1510), isRequired: true)
            ],
            checkpoints: [
            MapCheckpointDefinition(id: "checkpoint-sleeping-start", name: "Sleeping Room Start", checkpointID: .sleepingRoomStart, roomID: .sleepingRoom, position: CodablePoint(x: 1656.67, y: 2427.11), isRequired: true),
            MapCheckpointDefinition(id: "checkpoint-laboratory-entered", name: "Laboratory Entered", checkpointID: .laboratoryEntered, roomID: .laboratory, position: CodablePoint(x: 1283.56, y: 1376), isRequired: true),
            MapCheckpointDefinition(id: "checkpoint-laboratory-completed", name: "Laboratory Completed", checkpointID: .laboratoryCompleted, roomID: .laboratory, position: CodablePoint(x: 1283.56, y: 1376), isRequired: true),
            MapCheckpointDefinition(id: "checkpoint-engine-10", name: "Engine 10", checkpointID: .engine10, roomID: .engine, position: CodablePoint(x: 2369.78, y: 1749.33), isRequired: true),
            MapCheckpointDefinition(id: "checkpoint-engine-40", name: "Engine 40", checkpointID: .engine40, roomID: .engine, position: CodablePoint(x: 2369.78, y: 1749.33), isRequired: true),
            MapCheckpointDefinition(id: "checkpoint-engine-60", name: "Engine 60", checkpointID: .engine60, roomID: .engine, position: CodablePoint(x: 2369.78, y: 1749.33), isRequired: true),
            MapCheckpointDefinition(id: "checkpoint-advanced-tools", name: "Advanced Tools", checkpointID: .advancedToolsAcquired, roomID: .storage, position: CodablePoint(x: 3760, y: 1510), isRequired: true),
            MapCheckpointDefinition(id: "checkpoint-engine-100", name: "Engine 100", checkpointID: .engine100, roomID: .engine, position: CodablePoint(x: 2369.78, y: 1749.33), isRequired: true),
            MapCheckpointDefinition(id: "checkpoint-cockpit-entered", name: "Cockpit Entered", checkpointID: .cockpitEntered, roomID: .cockpit, position: CodablePoint(x: 2752, y: 2899.11), isRequired: true)
            ]
        )
    }
}
