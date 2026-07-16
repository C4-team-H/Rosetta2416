import CoreGraphics
import Testing
@testable import GameClassification

@Suite("Spaceship map reachability")
@MainActor
struct MapLayoutReachabilityTests {
    @Test("Every room is reachable when all doors are open", arguments: RoomID.allCases)
    func everyRoomIsReachable(room: RoomID) {
        #expect(routeExists(
            from: GameMapLayout.playerSpawnPosition,
            to: GameMapLayout.spawnPoint(for: room),
            closedDoors: []
        ))
    }

    @Test("Initial story doors preserve chapter gating")
    func initialDoorGating() {
        let closedDoors: Set<DoorID> = [.engine, .storage, .cockpit]

        #expect(routeExists(
            from: GameMapLayout.playerSpawnPosition,
            to: GameMapLayout.spawnPoint(for: .laboratory),
            closedDoors: closedDoors
        ))
        #expect(routeExists(
            from: GameMapLayout.playerSpawnPosition,
            to: GameMapLayout.spawnPoint(for: .kitchen),
            closedDoors: closedDoors
        ))
        #expect(!routeExists(
            from: GameMapLayout.playerSpawnPosition,
            to: GameMapLayout.spawnPoint(for: .engine),
            closedDoors: closedDoors
        ))
        #expect(!routeExists(
            from: GameMapLayout.playerSpawnPosition,
            to: GameMapLayout.spawnPoint(for: .storage),
            closedDoors: closedDoors
        ))
        #expect(!routeExists(
            from: GameMapLayout.playerSpawnPosition,
            to: GameMapLayout.spawnPoint(for: .cockpit),
            closedDoors: closedDoors
        ))
    }

    @Test("Door openings provide player clearance")
    func doorwayClearance() {
        let requiredOpening = GameMapLayout.playerFootprint.radius * 2 + GameMapLayout.scaled(20)
        for door in GameMapLayout.doorDefinitions {
            #expect(max(door.size.width, door.size.height) >= requiredOpening)
        }
    }

    private func routeExists(
        from start: CGPoint,
        to destination: CGPoint,
        closedDoors: Set<DoorID>
    ) -> Bool {
        struct GridPoint: Hashable {
            let x: Int
            let y: Int
        }

        let scale = GameMapLayout.artworkScale
        let step: CGFloat = 10
        func authoredPoint(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x / scale, y: point.y / scale)
        }
        func worldPoint(_ point: GridPoint) -> CGPoint {
            CGPoint(x: CGFloat(point.x) * step * scale, y: CGFloat(point.y) * step * scale)
        }

        let doorStates = Dictionary(uniqueKeysWithValues: DoorID.allCases.map {
            ($0, closedDoors.contains($0) ? DoorState.locked : DoorState.open)
        })
        let walkability = WalkabilitySystem(map: GameMapLayout.ship, doorStates: doorStates)

        let authoredStart = authoredPoint(start)
        let authoredDestination = authoredPoint(destination)

        func gridPoint(for point: CGPoint) -> GridPoint {
            GridPoint(x: Int((point.x / step).rounded()), y: Int((point.y / step).rounded()))
        }

        let startGrid = gridPoint(for: authoredStart)
        var queue = [startGrid]
        var visited: Set<GridPoint> = [startGrid]
        var cursor = 0
        let directions = [(1, 0), (-1, 0), (0, 1), (0, -1)]

        while cursor < queue.count {
            let current = queue[cursor]
            cursor += 1
            let point = CGPoint(x: CGFloat(current.x) * step, y: CGFloat(current.y) * step)
            if hypot(point.x - authoredDestination.x, point.y - authoredDestination.y) <= step { return true }

            for direction in directions {
                let next = GridPoint(x: current.x + direction.0, y: current.y + direction.1)
                guard visited.insert(next).inserted else { continue }
                guard next.x >= 0, next.y >= 0,
                      CGFloat(next.x) * step <= GameMapLayout.authoredArtworkSize.width,
                      CGFloat(next.y) * step <= GameMapLayout.authoredArtworkSize.height,
                      walkability.isWalkable(
                        position: worldPoint(next),
                        footprint: GameMapLayout.playerFootprint
                      ).isWalkable else { continue }
                queue.append(next)
            }
        }
        return false
    }
}
