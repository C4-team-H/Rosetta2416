import CoreGraphics

struct StationDefinition: Identifiable, Equatable {
    let id: String
    let roomID: RoomID
    let worldPosition: CGPoint
}

struct DoorDefinition: Identifiable, Equatable {
    let id: String
    let roomID: RoomID
    let worldPosition: CGPoint
    let size: CGSize
}

/// Shared geometry for SpriteKit collision, story room detection, and the tactical map.
enum GameMapLayout {
    static let worldSize = CGSize(width: 2_000, height: 2_000)
    static let playerSpawnPosition = CGPoint(x: 375, y: 1_000)
    static let foodStationPosition = CGPoint(x: 1_625, y: 400)

    static let rooms = [
        MapRoom(id: .sleepingRoom, name: "SLEEPING ROOM", worldFrame: CGRect(x: 200, y: 825, width: 350, height: 350)),
        MapRoom(id: .engine, name: "ENGINE ROOM", worldFrame: CGRect(x: 800, y: 800, width: 400, height: 400)),
        MapRoom(id: .laboratory, name: "LAB", worldFrame: CGRect(x: 200, y: 1_425, width: 350, height: 350)),
        MapRoom(id: .kitchen, name: "KITCHEN", worldFrame: CGRect(x: 1_450, y: 225, width: 350, height: 350)),
        MapRoom(id: .storage, name: "STORAGE", worldFrame: CGRect(x: 825, y: 1_425, width: 350, height: 350)),
        MapRoom(id: .cockpit, name: "COCKPIT", worldFrame: CGRect(x: 1_450, y: 1_425, width: 350, height: 350))
    ]

    static let corridors = [
        CGRect(x: 550, y: 950, width: 250, height: 100),
        CGRect(x: 325, y: 1_175, width: 100, height: 250),
        CGRect(x: 925, y: 1_200, width: 150, height: 225),
        CGRect(x: 1_175, y: 1_550, width: 275, height: 100),
        CGRect(x: 1_050, y: 350, width: 400, height: 100),
        CGRect(x: 950, y: 350, width: 100, height: 450)
    ]

    static let stationDefinitions: [StationDefinition] = {
        let ids = StoryContent.objectives.compactMap { objective -> StationDefinition? in
            guard case .drawing = objective.kind else { return nil }
            let position: CGPoint
            switch objective.roomID {
            case .laboratory:
                let index = StoryContent.labIDs.firstIndex(of: objective.id) ?? 0
                position = [CGPoint(x: 275, y: 1_600), CGPoint(x: 375, y: 1_600), CGPoint(x: 475, y: 1_600)][index]
            case .engine:
                let allEngineIDs = StoryContent.enginePhaseOneIDs + StoryContent.enginePhaseTwoIDs + StoryContent.engineFinalIDs
                let index = allEngineIDs.firstIndex(of: objective.id) ?? 0
                let columns: [CGFloat] = [850, 950, 1_050, 1_150]
                let rows: [CGFloat] = [860, 1_000, 1_140]
                position = CGPoint(x: columns[index % columns.count], y: rows[index / columns.count])
            case .storage:
                let index = StoryContent.storageIDs.firstIndex(of: objective.id) ?? 0
                position = [CGPoint(x: 900, y: 1_520), CGPoint(x: 1_100, y: 1_520), CGPoint(x: 900, y: 1_680), CGPoint(x: 1_100, y: 1_680)][index]
            case .cockpit:
                let index = StoryContent.cockpitIDs.firstIndex(of: objective.id) ?? 0
                position = [CGPoint(x: 1_530, y: 1_600), CGPoint(x: 1_625, y: 1_600), CGPoint(x: 1_720, y: 1_600)][index]
            case .sleepingRoom, .kitchen:
                return nil
            }
            return StationDefinition(id: objective.id, roomID: objective.roomID, worldPosition: position)
        }
        return ids
    }()

    static let doorDefinitions = [
        DoorDefinition(id: "engine-west-door", roomID: .engine, worldPosition: CGPoint(x: 800, y: 1_000), size: CGSize(width: 20, height: 100)),
        DoorDefinition(id: "storage-south-door", roomID: .storage, worldPosition: CGPoint(x: 1_000, y: 1_425), size: CGSize(width: 150, height: 20)),
        DoorDefinition(id: "cockpit-west-door", roomID: .cockpit, worldPosition: CGPoint(x: 1_450, y: 1_600), size: CGSize(width: 20, height: 100))
    ]

    static func room(containing point: CGPoint) -> RoomID? {
        rooms.first { $0.worldFrame.contains(point) }?.id
    }

    static func safeSpawn(for checkpoint: CheckpointID) -> CGPoint {
        switch checkpoint {
        case .sleepingRoom: playerSpawnPosition
        case .laboratory: CGPoint(x: 375, y: 1_520)
        case .enginePhaseOne, .engineDisruption, .engineBlocked, .engineFinal: CGPoint(x: 1_000, y: 1_000)
        case .storage: CGPoint(x: 1_000, y: 1_600)
        case .cockpit: CGPoint(x: 1_625, y: 1_600)
        }
    }

    static let wallSegments: [MapWallSegment] = {
        let endpoints: [(CGPoint, CGPoint)] = [
            // Sleeping Room
            (CGPoint(x: 200, y: 825), CGPoint(x: 200, y: 1_175)),
            (CGPoint(x: 200, y: 1_175), CGPoint(x: 325, y: 1_175)),
            (CGPoint(x: 425, y: 1_175), CGPoint(x: 550, y: 1_175)),
            (CGPoint(x: 200, y: 825), CGPoint(x: 550, y: 825)),
            (CGPoint(x: 550, y: 825), CGPoint(x: 550, y: 950)),
            (CGPoint(x: 550, y: 1_050), CGPoint(x: 550, y: 1_175)),

            // Engine Room
            (CGPoint(x: 800, y: 800), CGPoint(x: 800, y: 950)),
            (CGPoint(x: 800, y: 1_050), CGPoint(x: 800, y: 1_200)),
            (CGPoint(x: 1_200, y: 800), CGPoint(x: 1_200, y: 1_200)),
            (CGPoint(x: 800, y: 1_200), CGPoint(x: 950, y: 1_200)),
            (CGPoint(x: 1_050, y: 1_200), CGPoint(x: 1_200, y: 1_200)),
            (CGPoint(x: 800, y: 800), CGPoint(x: 950, y: 800)),
            (CGPoint(x: 1_050, y: 800), CGPoint(x: 1_200, y: 800)),

            // Lab
            (CGPoint(x: 200, y: 1_425), CGPoint(x: 200, y: 1_775)),
            (CGPoint(x: 200, y: 1_775), CGPoint(x: 550, y: 1_775)),
            (CGPoint(x: 550, y: 1_425), CGPoint(x: 550, y: 1_775)),
            (CGPoint(x: 200, y: 1_425), CGPoint(x: 325, y: 1_425)),
            (CGPoint(x: 425, y: 1_425), CGPoint(x: 550, y: 1_425)),

            // Storage
            // Keep both entrances wider than the player's collision diameter.
            // South/front entrance: x 925...1,075.
            (CGPoint(x: 825, y: 1_425), CGPoint(x: 925, y: 1_425)),
            (CGPoint(x: 1_075, y: 1_425), CGPoint(x: 1_175, y: 1_425)),
            (CGPoint(x: 825, y: 1_425), CGPoint(x: 825, y: 1_775)),
            (CGPoint(x: 825, y: 1_775), CGPoint(x: 1_175, y: 1_775)),
            // East/side entrance: y 1,525...1,675.
            (CGPoint(x: 1_175, y: 1_425), CGPoint(x: 1_175, y: 1_525)),
            (CGPoint(x: 1_175, y: 1_675), CGPoint(x: 1_175, y: 1_775)),

            // Cockpit
            (CGPoint(x: 1_450, y: 1_425), CGPoint(x: 1_800, y: 1_425)),
            (CGPoint(x: 1_450, y: 1_775), CGPoint(x: 1_800, y: 1_775)),
            (CGPoint(x: 1_800, y: 1_425), CGPoint(x: 1_800, y: 1_775)),
            (CGPoint(x: 1_450, y: 1_425), CGPoint(x: 1_450, y: 1_550)),
            (CGPoint(x: 1_450, y: 1_650), CGPoint(x: 1_450, y: 1_775)),

            // Kitchen
            (CGPoint(x: 1_800, y: 225), CGPoint(x: 1_800, y: 575)),
            (CGPoint(x: 1_450, y: 575), CGPoint(x: 1_800, y: 575)),
            (CGPoint(x: 1_450, y: 225), CGPoint(x: 1_800, y: 225)),
            (CGPoint(x: 1_450, y: 225), CGPoint(x: 1_450, y: 350)),
            (CGPoint(x: 1_450, y: 450), CGPoint(x: 1_450, y: 575)),

            // Corridors
            (CGPoint(x: 550, y: 1_050), CGPoint(x: 800, y: 1_050)),
            (CGPoint(x: 550, y: 950), CGPoint(x: 800, y: 950)),
            // Direct Sleeping Room–Lab corridor. This route must remain open
            // before the Engine Room is unlocked by the Laboratory chapter.
            (CGPoint(x: 325, y: 1_175), CGPoint(x: 325, y: 1_425)),
            // Keep this side closed so there is no direct Lab–Storage branch.
            (CGPoint(x: 425, y: 1_175), CGPoint(x: 425, y: 1_425)),
            // Engine–Storage corridor.
            (CGPoint(x: 925, y: 1_200), CGPoint(x: 925, y: 1_425)),
            (CGPoint(x: 1_075, y: 1_200), CGPoint(x: 1_075, y: 1_425)),
            (CGPoint(x: 1_175, y: 1_525), CGPoint(x: 1_450, y: 1_525)),
            (CGPoint(x: 1_175, y: 1_675), CGPoint(x: 1_450, y: 1_675)),
            (CGPoint(x: 1_450, y: 450), CGPoint(x: 1_050, y: 450)),
            (CGPoint(x: 1_050, y: 450), CGPoint(x: 1_050, y: 800)),
            (CGPoint(x: 1_450, y: 350), CGPoint(x: 950, y: 350)),
            (CGPoint(x: 950, y: 350), CGPoint(x: 950, y: 800))
        ]
        return endpoints.enumerated().map { MapWallSegment(id: $0.offset, start: $0.element.0, end: $0.element.1) }
    }()

    static var defaultMarkers: [MapMarker] {
        let story = StoryProgressionSystem()
        return TacticalMapMarkerFactory.make(story: story, includeDoors: true)
    }
}
