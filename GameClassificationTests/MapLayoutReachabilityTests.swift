import CoreGraphics
import Testing
@testable import GameClassification

@Suite("Chapter one map reachability")
struct MapLayoutReachabilityTests {
    @Test("Laboratory is reachable while the Engine door remains locked")
    func laboratoryRouteBypassesLockedEngine() {
        let initialStory = SharedStoryState.initial
        #expect(!StoryContent.roomRules.first(where: { $0.roomID == .engine })!.allows(initialStory))
        #expect(routeExists(
            from: GameMapLayout.playerSpawnPosition,
            to: GameMapLayout.rooms.first(where: { $0.id == .laboratory })!.worldFrame,
            story: initialStory
        ))
    }

    private func routeExists(from start: CGPoint, to destination: CGRect, story: SharedStoryState) -> Bool {
        let step: CGFloat = 20
        let radius: CGFloat = 15
        let wallThickness: CGFloat = 16
        var blockedRects = GameMapLayout.wallSegments.map { wall -> CGRect in
            let minX = min(wall.start.x, wall.end.x)
            let minY = min(wall.start.y, wall.end.y)
            return CGRect(
                x: minX - wallThickness / 2,
                y: minY - wallThickness / 2,
                width: max(abs(wall.end.x - wall.start.x), wallThickness),
                height: max(abs(wall.end.y - wall.start.y), wallThickness)
            ).insetBy(dx: -radius, dy: -radius)
        }
        blockedRects += GameMapLayout.doorDefinitions.compactMap { door in
            guard let rule = StoryContent.roomRules.first(where: { $0.roomID == door.roomID }),
                  !rule.allows(story) else { return nil }
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

        func worldPoint(_ grid: GridPoint) -> CGPoint {
            CGPoint(x: start.x + CGFloat(grid.x) * step, y: start.y + CGFloat(grid.y) * step)
        }

        var queue = [GridPoint(x: 0, y: 0)]
        var visited: Set<GridPoint> = [queue[0]]
        var cursor = 0
        let directions = [(1, 0), (-1, 0), (0, 1), (0, -1)]

        while cursor < queue.count {
            let current = queue[cursor]
            cursor += 1
            let point = worldPoint(current)
            if destination.insetBy(dx: radius, dy: radius).contains(point) { return true }

            for direction in directions {
                let next = GridPoint(x: current.x + direction.0, y: current.y + direction.1)
                guard visited.insert(next).inserted else { continue }
                let nextPoint = worldPoint(next)
                guard nextPoint.x >= radius,
                      nextPoint.y >= radius,
                      nextPoint.x <= GameMapLayout.worldSize.width - radius,
                      nextPoint.y <= GameMapLayout.worldSize.height - radius,
                      !blockedRects.contains(where: { $0.contains(nextPoint) }) else { continue }
                queue.append(next)
            }
        }
        return false
    }
}
