import CoreGraphics

/// The single source of truth for both the SpriteKit level and its tactical map.
enum GameMapLayout {
    static let worldSize = CGSize(width: 2_000, height: 2_000)
    static let playerSpawnPosition = CGPoint(x: 375, y: 1_000)
    static let challengeStationPositions = [
        CGPoint(x: 1_000, y: 1_000),
        CGPoint(x: 375, y: 1_600)
    ]
    static let foodStationPosition = CGPoint(x: 1_625, y: 400)

    static let rooms = [
        MapRoom(name: "SLEEPING ROOM", worldFrame: CGRect(x: 200, y: 825, width: 350, height: 350)),
        MapRoom(name: "ENGINE ROOM", worldFrame: CGRect(x: 800, y: 800, width: 400, height: 400)),
        MapRoom(name: "LAB", worldFrame: CGRect(x: 200, y: 1_425, width: 350, height: 350)),
        MapRoom(name: "KITCHEN", worldFrame: CGRect(x: 1_450, y: 225, width: 350, height: 350))
    ]

    /// Walkable path footprints. Wall segments below define the exact collision boundary.
    static let corridors = [
        CGRect(x: 550, y: 950, width: 250, height: 100),
        CGRect(x: 325, y: 1_350, width: 100, height: 75),
        CGRect(x: 325, y: 1_250, width: 725, height: 100),
        CGRect(x: 950, y: 1_200, width: 100, height: 50),
        CGRect(x: 1_050, y: 350, width: 400, height: 100),
        CGRect(x: 950, y: 350, width: 100, height: 450)
    ]

    static let wallSegments: [MapWallSegment] = {
        let endpoints: [(CGPoint, CGPoint)] = [
            // Sleeping room
            (CGPoint(x: 200, y: 825), CGPoint(x: 200, y: 1_175)),
            (CGPoint(x: 200, y: 1_175), CGPoint(x: 550, y: 1_175)),
            (CGPoint(x: 200, y: 825), CGPoint(x: 550, y: 825)),
            (CGPoint(x: 550, y: 825), CGPoint(x: 550, y: 950)),
            (CGPoint(x: 550, y: 1_050), CGPoint(x: 550, y: 1_175)),

            // Engine room
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

            // Kitchen
            (CGPoint(x: 1_800, y: 225), CGPoint(x: 1_800, y: 575)),
            (CGPoint(x: 1_450, y: 575), CGPoint(x: 1_800, y: 575)),
            (CGPoint(x: 1_450, y: 225), CGPoint(x: 1_800, y: 225)),
            (CGPoint(x: 1_450, y: 225), CGPoint(x: 1_450, y: 350)),
            (CGPoint(x: 1_450, y: 450), CGPoint(x: 1_450, y: 575)),

            // Sleeping-to-engine corridor
            (CGPoint(x: 550, y: 1_050), CGPoint(x: 800, y: 1_050)),
            (CGPoint(x: 550, y: 950), CGPoint(x: 800, y: 950)),

            // Lab-to-engine corridor
            (CGPoint(x: 325, y: 1_425), CGPoint(x: 325, y: 1_250)),
            (CGPoint(x: 325, y: 1_250), CGPoint(x: 950, y: 1_250)),
            (CGPoint(x: 950, y: 1_250), CGPoint(x: 950, y: 1_200)),
            (CGPoint(x: 425, y: 1_425), CGPoint(x: 425, y: 1_350)),
            (CGPoint(x: 425, y: 1_350), CGPoint(x: 1_050, y: 1_350)),
            (CGPoint(x: 1_050, y: 1_350), CGPoint(x: 1_050, y: 1_200)),

            // Kitchen-to-engine corridor
            (CGPoint(x: 1_450, y: 450), CGPoint(x: 1_050, y: 450)),
            (CGPoint(x: 1_050, y: 450), CGPoint(x: 1_050, y: 800)),
            (CGPoint(x: 1_450, y: 350), CGPoint(x: 950, y: 350)),
            (CGPoint(x: 950, y: 350), CGPoint(x: 950, y: 800))
        ]

        return endpoints.enumerated().map { index, points in
            MapWallSegment(id: index, start: points.0, end: points.1)
        }
    }()

    static let defaultMarkers = [
        MapMarker(type: .activeMission, worldPosition: challengeStationPositions[0], title: "Engine Sketch"),
        MapMarker(type: .activeMission, worldPosition: challengeStationPositions[1], title: "Lab Study"),
        MapMarker(type: .importantObject, worldPosition: foodStationPosition, title: "Energy Station"),
        MapMarker(type: .lockedArea, worldPosition: CGPoint(x: 1_000, y: 1_840), title: "North Gate"),
        MapMarker(type: .checkpoint, worldPosition: CGPoint(x: 1_000, y: 700), title: "Rally Point"),
        MapMarker(type: .door, worldPosition: CGPoint(x: 550, y: 1_000), title: "Sleeping Door"),
        MapMarker(type: .door, worldPosition: CGPoint(x: 800, y: 1_000), title: "Engine West Door"),
        MapMarker(type: .door, worldPosition: CGPoint(x: 1_000, y: 1_200), title: "Engine North Door"),
        MapMarker(type: .door, worldPosition: CGPoint(x: 1_000, y: 800), title: "Engine South Door"),
        MapMarker(type: .door, worldPosition: CGPoint(x: 375, y: 1_425), title: "Lab Door"),
        MapMarker(type: .door, worldPosition: CGPoint(x: 1_450, y: 400), title: "Kitchen Door")
    ]
}
