import CoreGraphics
import Foundation

struct StationDefinition: Identifiable, Equatable {
    let id: String
    let roomID: RoomID
    let worldPosition: CGPoint
}

enum DoorID: String, CaseIterable, Sendable {
    case cockpit
    case sleepingRoom
    case kitchen
    case engine
    case laboratory
    case storage

    var nodeName: String { "door-\(rawValue)" }
    var displayName: String { "\(roomID.displayName) Door" }

    var roomID: RoomID {
        switch self {
        case .cockpit: .cockpit
        case .sleepingRoom: .sleepingRoom
        case .kitchen: .kitchen
        case .engine: .engine
        case .laboratory: .laboratory
        case .storage: .storage
        }
    }
}

struct DoorDefinition: Identifiable, Equatable {
    let id: DoorID
    let roomID: RoomID
    let worldPosition: CGPoint
    let size: CGSize
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
    let roomID: RoomID
    let worldFrame: CGRect
}

struct SpawnPointDefinition: Identifiable, Equatable {
    var id: RoomID { roomID }
    let roomID: RoomID
    let worldPosition: CGPoint
}

/// Shared 1440 x 1080 geometry for SpriteKit, story state, and the tactical map.
///
/// Authoring values below use the reference image's top-left origin. Conversion
/// happens once through `worldPoint` and `worldRect`, so collider tuning can be
/// performed directly against ShipMap.jpg while SpriteKit receives bottom-left
/// world coordinates.
enum GameMapLayout {
    static let worldSize = CGSize(width: 1_440, height: 1_080)
    static let playerRadius: CGFloat = 15
    static let wallThickness: CGFloat = 16

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
        var converted: [CGPoint] = []
        converted.reserveCapacity(points.count)
        for point in points {
            converted.append(worldPoint(fromImagePoint: point))
        }
        return converted
    }

    // Room triggers are inset from walls and stop before the shared corridors.
    static let roomTriggerDefinitions: [RoomTriggerDefinition] = [
        room(.cockpit, imageRect: CGRect(x: 595, y: 130, width: 250, height: 285)),
        room(.sleepingRoom, imageRect: CGRect(x: 190, y: 295, width: 295, height: 220)),
        room(.kitchen, imageRect: CGRect(x: 945, y: 295, width: 230, height: 200)),
        room(.engine, imageRect: CGRect(x: 595, y: 545, width: 250, height: 245)),
        room(.laboratory, imageRect: CGRect(x: 115, y: 545, width: 370, height: 330)),
        room(.storage, imageRect: CGRect(x: 955, y: 545, width: 350, height: 330))
    ]

    static let rooms: [MapRoom] = roomTriggerDefinitions.map { definition in
        MapRoom(
            id: definition.roomID,
            name: definition.roomID.displayName.uppercased(),
            worldFrame: definition.worldFrame
        )
    }

    // These areas describe navigable topology for the tactical map and tests.
    static let corridors: [CGRect] = [
        imageRect(500, 430, 440, 100), // Main port-starboard corridor.
        imageRect(500, 430, 80, 260), // Sleeping Room to Lab Room.
        imageRect(680, 410, 80, 140), // Cockpit to Engine Room.
        imageRect(860, 430, 80, 260) // Kitchen to Storage Room.
    ]

    static let walkableAreas: [CGRect] = [
        imageRect(175, 280, 325, 250),
        imageRect(580, 115, 280, 315),
        imageRect(940, 280, 250, 250),
        imageRect(580, 530, 280, 275),
        imageRect(100, 530, 400, 370),
        imageRect(940, 530, 380, 370)
    ] + corridors

    static let spawnPoints: [SpawnPointDefinition] = [
        spawn(.sleepingRoom, imagePoint: CGPoint(x: 300, y: 445)),
        spawn(.laboratory, imagePoint: CGPoint(x: 430, y: 720)),
        spawn(.engine, imagePoint: CGPoint(x: 620, y: 570)),
        spawn(.kitchen, imagePoint: CGPoint(x: 970, y: 380)),
        spawn(.storage, imagePoint: CGPoint(x: 975, y: 690)),
        spawn(.cockpit, imagePoint: CGPoint(x: 720, y: 400))
    ]

    static let playerSpawnPosition = spawnPoint(for: .sleepingRoom)
    static let foodStationPosition = worldPoint(fromImagePoint: CGPoint(x: 970, y: 400))

    static let stationDefinitions: [StationDefinition] = {
        let labPoints = imagePoints([
            (290, 650), (390, 650), (230, 760)
        ])
        let enginePoints = imagePoints([
            (620, 570), (720, 570), (810, 570), (835, 590),
            (620, 680), (835, 680), (620, 760), (835, 760),
            (660, 785), (720, 785), (780, 785), (825, 785)
        ])
        let storagePoints = imagePoints([
            (980, 650), (1_210, 650), (970, 840), (1_200, 865)
        ])
        let cockpitPoints = imagePoints([
            (620, 250), (720, 310), (835, 250)
        ])

        return StoryContent.objectives.compactMap { objective -> StationDefinition? in
            guard case .drawing = objective.kind else { return nil }
            let worldPosition: CGPoint?
            switch objective.roomID {
            case .laboratory:
                worldPosition = point(for: objective.id, in: StoryContent.labIDs, points: labPoints)
            case .engine:
                let ids = StoryContent.enginePhaseOneIDs + StoryContent.enginePhaseTwoIDs + StoryContent.engineFinalIDs
                worldPosition = point(for: objective.id, in: ids, points: enginePoints)
            case .storage:
                worldPosition = point(for: objective.id, in: StoryContent.storageIDs, points: storagePoints)
            case .cockpit:
                worldPosition = point(for: objective.id, in: StoryContent.cockpitIDs, points: cockpitPoints)
            case .sleepingRoom, .kitchen:
                worldPosition = nil
            }
            guard let worldPosition else { return nil }
            return StationDefinition(id: objective.id, roomID: objective.roomID, worldPosition: worldPosition)
        }
    }()

    // Door rectangles occupy intentional gaps in the room perimeter segments.
    static let doorDefinitions: [DoorDefinition] = [
        door(.cockpit, imageRect: CGRect(x: 680, y: 421, width: 80, height: 18)),
        door(.sleepingRoom, imageRect: CGRect(x: 491, y: 420, width: 18, height: 80)),
        door(.kitchen, imageRect: CGRect(x: 931, y: 400, width: 18, height: 100)),
        door(.engine, imageRect: CGRect(x: 680, y: 521, width: 80, height: 18)),
        door(.laboratory, imageRect: CGRect(x: 491, y: 610, width: 18, height: 80)),
        door(.storage, imageRect: CGRect(x: 931, y: 610, width: 18, height: 80))
    ]

    static let wallSegments: [MapWallSegment] = {
        let imageSegments: [(CGPoint, CGPoint)] = [
            // Cockpit perimeter, with a bottom-center doorway.
            segment(580, 115, 860, 115), segment(580, 115, 580, 430),
            segment(860, 115, 860, 430), segment(580, 430, 680, 430),
            segment(760, 430, 860, 430),

            // Sleeping Room, doorway on the starboard wall.
            segment(175, 280, 500, 280), segment(175, 280, 175, 530),
            segment(175, 530, 500, 530), segment(500, 280, 500, 420),
            segment(500, 500, 500, 530),

            // Kitchen, doorway on the port wall.
            segment(940, 280, 1_190, 280), segment(1_190, 280, 1_190, 530),
            segment(940, 530, 1_190, 530), segment(940, 280, 940, 400),
            segment(940, 500, 940, 530),

            // Engine Room, doorway on the forward wall.
            segment(580, 530, 680, 530), segment(760, 530, 860, 530),
            segment(580, 530, 580, 805), segment(860, 530, 860, 805),
            segment(580, 805, 860, 805),

            // Lab Room, doorway on the starboard wall.
            segment(100, 530, 500, 530), segment(100, 530, 100, 900),
            segment(100, 900, 500, 900), segment(500, 530, 500, 610),
            segment(500, 690, 500, 900),

            // Storage Room, doorway on the port wall.
            segment(940, 530, 1_320, 530), segment(1_320, 530, 1_320, 900),
            segment(940, 900, 1_320, 900), segment(940, 530, 940, 610),
            segment(940, 690, 940, 900)
        ]

        return imageSegments.enumerated().map { index, endpoints in
            MapWallSegment(
                id: index,
                start: worldPoint(fromImagePoint: endpoints.0),
                end: worldPoint(fromImagePoint: endpoints.1)
            )
        }
    }()

    static let colliderDefinitions: [ShipColliderDefinition] = {
        var definitions: [ShipColliderDefinition] = [
            ShipColliderDefinition(
                id: "outer-hull",
                kind: .hull,
                shape: .edgeLoop(worldPoints(fromImagePoints: [
                    CGPoint(x: 500, y: 100), CGPoint(x: 940, y: 100),
                    CGPoint(x: 980, y: 260), CGPoint(x: 1_210, y: 275),
                    CGPoint(x: 1_340, y: 500), CGPoint(x: 1_390, y: 920),
                    CGPoint(x: 50, y: 920), CGPoint(x: 100, y: 500),
                    CGPoint(x: 230, y: 275), CGPoint(x: 460, y: 260)
                ])),
                debugLabel: "Outer Hull"
            )
        ]

        let furniture: [(String, ShipColliderKind, CGRect)] = [
            // Cockpit.
            ("cockpit-main-console", .machinery, rect(590, 190, 250, 48)),
            ("cockpit-pilot-chair", .furniture, rect(700, 235, 40, 68)),
            ("cockpit-navigation-display", .machinery, rect(760, 250, 88, 150)),
            ("cockpit-port-machinery", .machinery, rect(590, 250, 35, 130)),

            // Sleeping Room.
            ("sleeping-bed", .furniture, rect(330, 295, 160, 80)),
            ("sleeping-main-console", .machinery, rect(380, 420, 75, 80)),
            ("sleeping-storage", .furniture, rect(200, 320, 55, 72)),

            // Kitchen.
            ("kitchen-main-counter", .furniture, rect(1_000, 465, 140, 42)),
            ("kitchen-side-counter", .furniture, rect(1_055, 330, 90, 120)),
            ("kitchen-sink-stove", .machinery, rect(1_000, 405, 55, 45)),
            ("kitchen-appliance", .machinery, rect(945, 285, 85, 55)),

            // Engine Room.
            ("engine-core", .machinery, rect(650, 600, 160, 170)),
            // Keep the doorway approach and the port-side service lane clear.
            ("engine-battery-bank", .machinery, rect(755, 555, 70, 38)),
            ("engine-port-pipes", .machinery, rect(590, 610, 38, 125)),
            ("engine-starboard-equipment", .machinery, rect(830, 610, 25, 125)),

            // Lab Room.
            ("lab-main-table", .furniture, rect(260, 555, 200, 70)),
            ("lab-microscope-station", .furniture, rect(125, 725, 120, 100)),
            ("lab-lower-bench", .furniture, rect(285, 800, 210, 65)),
            ("lab-shelf", .furniture, rect(435, 550, 40, 50)),

            // Storage Room.
            ("storage-cabinets", .furniture, rect(1_000, 545, 190, 85)),
            ("storage-crates", .furniture, rect(1_000, 700, 110, 100)),
            ("storage-containers", .furniture, rect(1_090, 760, 105, 105)),
            ("storage-tool-rack", .furniture, rect(1_210, 720, 85, 145)),
            ("storage-machinery", .machinery, rect(1_140, 650, 80, 72))
        ]

        definitions += furniture.map { id, kind, imageFrame in
            ShipColliderDefinition(
                id: id,
                kind: kind,
                shape: .rectangle(worldRect(fromImageRect: imageFrame)),
                debugLabel: id.replacingOccurrences(of: "-", with: " ").capitalized
            )
        }
        return definitions
    }()

    static var blockingRectangles: [CGRect] {
        let walls = wallSegments.map { segment in
            let minX = min(segment.start.x, segment.end.x)
            let minY = min(segment.start.y, segment.end.y)
            return CGRect(
                x: minX - wallThickness / 2,
                y: minY - wallThickness / 2,
                width: max(abs(segment.end.x - segment.start.x), wallThickness),
                height: max(abs(segment.end.y - segment.start.y), wallThickness)
            )
        }
        let furniture = colliderDefinitions.compactMap { definition -> CGRect? in
            guard case let .rectangle(rect) = definition.shape else { return nil }
            return rect
        }
        return walls + furniture
    }

    static func room(containing point: CGPoint) -> RoomID? {
        roomTriggerDefinitions.first { $0.worldFrame.contains(point) }?.roomID
    }

    static func spawnPoint(for room: RoomID) -> CGPoint {
        spawnPoints.first(where: { $0.roomID == room })?.worldPosition
            ?? CGPoint(x: worldSize.width / 2, y: worldSize.height / 2)
    }

    static func safeSpawn(for checkpoint: CheckpointID) -> CGPoint {
        switch checkpoint {
        case .sleepingRoom: spawnPoint(for: .sleepingRoom)
        case .laboratory: spawnPoint(for: .laboratory)
        case .enginePhaseOne, .engineDisruption, .engineBlocked, .engineFinal: spawnPoint(for: .engine)
        case .storage: spawnPoint(for: .storage)
        case .cockpit: spawnPoint(for: .cockpit)
        }
    }

    static var defaultMarkers: [MapMarker] {
        let story = StoryProgressionSystem()
        return TacticalMapMarkerFactory.make(story: story, includeDoors: true)
    }

    private static func imageRect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
        worldRect(fromImageRect: CGRect(x: x, y: y, width: width, height: height))
    }

    private static func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    private static func segment(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) -> (CGPoint, CGPoint) {
        (CGPoint(x: x1, y: y1), CGPoint(x: x2, y: y2))
    }

    private static func imagePoints(_ points: [(CGFloat, CGFloat)]) -> [CGPoint] {
        points.map { worldPoint(fromImagePoint: CGPoint(x: $0.0, y: $0.1)) }
    }

    private static func point(for id: String, in ids: [String], points: [CGPoint]) -> CGPoint? {
        guard let index = ids.firstIndex(of: id), points.indices.contains(index) else { return nil }
        return points[index]
    }

    private static func room(_ roomID: RoomID, imageRect: CGRect) -> RoomTriggerDefinition {
        RoomTriggerDefinition(roomID: roomID, worldFrame: worldRect(fromImageRect: imageRect))
    }

    private static func spawn(_ roomID: RoomID, imagePoint: CGPoint) -> SpawnPointDefinition {
        SpawnPointDefinition(roomID: roomID, worldPosition: worldPoint(fromImagePoint: imagePoint))
    }

    private static func door(_ id: DoorID, imageRect: CGRect) -> DoorDefinition {
        let worldFrame = worldRect(fromImageRect: imageRect)
        return DoorDefinition(
            id: id,
            roomID: id.roomID,
            worldPosition: CGPoint(x: worldFrame.midX, y: worldFrame.midY),
            size: worldFrame.size
        )
    }
}
