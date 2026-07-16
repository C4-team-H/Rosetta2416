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
        let requiredOpening = GameMapLayout.playerRadius * 2 + 20
        for door in GameMapLayout.doorDefinitions {
            #expect(max(door.size.width, door.size.height) >= requiredOpening)
        }
    }

    private func routeExists(
        from start: CGPoint,
        to destination: CGPoint,
        closedDoors: Set<DoorID>
    ) -> Bool {
        let step: CGFloat = 10
        let radius = GameMapLayout.playerRadius
        var blockedRects = GameMapLayout.blockingRectangles.map {
            $0.insetBy(dx: -radius, dy: -radius)
        }
        blockedRects += GameMapLayout.doorDefinitions.compactMap { door in
            guard closedDoors.contains(door.id) else { return nil }
            return CGRect(
                x: door.worldPosition.x - door.size.width / 2,
                y: door.worldPosition.y - door.size.height / 2,
                width: door.size.width,
                height: door.size.height
            ).insetBy(dx: -radius, dy: -radius)
        }

        struct GridPoint: Hashable {
            let x: Int
            let y: Int
        }

        func gridPoint(for point: CGPoint) -> GridPoint {
            GridPoint(x: Int((point.x / step).rounded()), y: Int((point.y / step).rounded()))
        }

        func worldPoint(_ point: GridPoint) -> CGPoint {
            CGPoint(x: CGFloat(point.x) * step, y: CGFloat(point.y) * step)
        }

        let startGrid = gridPoint(for: start)
        var queue = [startGrid]
        var visited: Set<GridPoint> = [startGrid]
        var cursor = 0
        let directions = [(1, 0), (-1, 0), (0, 1), (0, -1)]

        while cursor < queue.count {
            let current = queue[cursor]
            cursor += 1
            let point = worldPoint(current)
            if hypot(point.x - destination.x, point.y - destination.y) <= step { return true }

            for direction in directions {
                let next = GridPoint(x: current.x + direction.0, y: current.y + direction.1)
                guard visited.insert(next).inserted else { continue }
                let nextPoint = worldPoint(next)
                guard GameMapLayout.walkableAreas.contains(where: { $0.contains(nextPoint) }),
                      !blockedRects.contains(where: { $0.contains(nextPoint) }) else { continue }
                queue.append(next)
            }
        }
        return false
    }
}
