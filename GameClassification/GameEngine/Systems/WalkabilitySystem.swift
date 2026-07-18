import CoreGraphics
import Foundation

final class WalkabilitySystem {
    private(set) var map: GameMap
    private(set) var doorStates: [DoorID: DoorState]

    init(
        map: GameMap,
        doorStates: [DoorID: DoorState] = Dictionary(
            uniqueKeysWithValues: DoorID.allCases.map { ($0, .closed) }
        )
    ) {
        self.map = map
        self.doorStates = doorStates
    }

    func updateDoorState(_ state: DoorState, for doorID: DoorID) {
        doorStates[doorID] = state
    }

    func updateDoorStates(_ states: [DoorID: DoorState]) {
        doorStates = states
    }

    func replaceMap(_ map: GameMap) {
        self.map = map
        let validDoorIDs = Set(map.doorways.map(\.id))
        doorStates = doorStates.filter { validDoorIDs.contains($0.key) }
        for doorway in map.doorways where doorStates[doorway.id] == nil {
            doorStates[doorway.id] = .closed
        }
    }

    func isWalkable(
        position: CGPoint,
        footprint: CollisionFootprint
    ) -> WalkabilityResult {
        isWalkable(position: position, footprint: footprint, doorStates: doorStates)
    }

    func isWalkable(
        position: CGPoint,
        footprint: CollisionFootprint,
        doorStates: [DoorID: DoorState]
    ) -> WalkabilityResult {
        guard position.x.isFinite, position.y.isFinite,
              footprint.centerOffset.x.isFinite, footprint.centerOffset.y.isFinite,
              footprint.width.isFinite, footprint.width > 0,
              footprint.height.isFinite, footprint.height > 0,
              footprint.obstacleRadius.isFinite, footprint.obstacleRadius > 0 else {
            return .blocked(.invalid)
        }

        let center = footprint.center(at: position)
        let worldFrame = CGRect(origin: .zero, size: map.configuration.worldSize)
        guard worldFrame.contains(center) else { return .blocked(.outsideShip) }

        if let doorBlock = blockingDoor(
            center: center,
            radius: footprint.radius,
            doorStates: doorStates
        ) {
            return .blocked(doorBlock)
        }

        if intersectsWall(center: center, radius: footprint.radius) {
            return .blocked(.wall)
        }

        if intersectsObstacle(center: center, radius: footprint.obstacleRadius) {
            return .blocked(.obstacle)
        }

        let samplePoints = footprint.samplePoints(at: position)
        guard samplePoints.allSatisfy({ point in
            areaType(containing: point, doorStates: doorStates) != nil
        }) else {
            return .blocked(.outsideShip)
        }

        guard let centerArea = areaType(containing: center, doorStates: doorStates) else {
            return .blocked(.outsideShip)
        }
        return .walkable(centerArea)
    }

    func nearestWalkablePosition(
        to target: CGPoint,
        from source: CGPoint,
        footprint: CollisionFootprint
    ) -> CGPoint? {
        nearestWalkablePosition(
            to: target,
            from: source,
            footprint: footprint,
            doorStates: doorStates
        )
    }

    func nearestWalkablePosition(
        to target: CGPoint,
        from source: CGPoint,
        footprint: CollisionFootprint,
        doorStates: [DoorID: DoorState]
    ) -> CGPoint? {
        guard target.x.isFinite, target.y.isFinite else { return nil }
        if isWalkable(position: target, footprint: footprint, doorStates: doorStates).isWalkable {
            return target
        }

        let step = map.configuration.targetClampStep
        let maximumRadius = map.configuration.targetClampMaximumRadius
        guard step > 0, maximumRadius >= step else { return nil }

        var radius = step
        while radius <= maximumRadius + map.configuration.walkabilityEpsilon {
            let sampleCount = max(8, Int(ceil((2 * .pi * radius) / step)))
            var candidates: [CGPoint] = []
            candidates.reserveCapacity(sampleCount)
            for index in 0..<sampleCount {
                let angle = (2 * CGFloat.pi * CGFloat(index)) / CGFloat(sampleCount)
                let candidate = CGPoint(
                    x: target.x + cos(angle) * radius,
                    y: target.y + sin(angle) * radius
                )
                if isWalkable(
                    position: candidate,
                    footprint: footprint,
                    doorStates: doorStates
                ).isWalkable {
                    candidates.append(candidate)
                }
            }
            if let nearest = candidates.min(by: {
                squaredDistance($0, source) < squaredDistance($1, source)
            }) {
                return nearest
            }
            radius += step
        }
        return nil
    }

    private func areaType(
        containing point: CGPoint,
        doorStates: [DoorID: DoorState]
    ) -> WalkableAreaType? {
        let epsilon = map.configuration.walkabilityEpsilon

        if map.doorways.contains(where: { doorway in
            doorStates[doorway.id, default: .closed] == .open
                && shapeContains(doorway.shape, point: point, epsilon: epsilon)
        }) {
            return .doorway
        }
        if map.rooms.contains(where: {
            shapeContains($0.walkableShape, point: point, epsilon: epsilon)
        }) {
            return .room
        }
        if map.corridors.contains(where: {
            shapeContains($0.shape, point: point, epsilon: epsilon)
        }) {
            return .corridor
        }
        return nil
    }

    private func blockingDoor(
        center: CGPoint,
        radius: CGFloat,
        doorStates: [DoorID: DoorState]
    ) -> BlockedAreaType? {
        for doorway in map.doorways {
            let state = doorStates[doorway.id, default: .closed]
            guard state.blocksMovement,
                  circleIntersects(
                    shape: doorway.shape,
                    center: center,
                    radius: radius,
                    epsilon: map.configuration.walkabilityEpsilon
                  ) else { continue }
            return state == .locked ? .lockedDoor : .closedDoor
        }
        return nil
    }

    private func intersectsWall(center: CGPoint, radius: CGFloat) -> Bool {
        let effectiveRadius = radius + map.configuration.wallThickness / 2
            - map.configuration.walkabilityEpsilon
        let hasExplicitWallColliders = map.colliders.contains { $0.kind == .interiorWall }
        if !hasExplicitWallColliders, map.wallSegments.contains(where: {
            squaredDistanceFromPoint(center, toSegmentFrom: $0.start, to: $0.end)
                < effectiveRadius * effectiveRadius
        }) {
            return true
        }

        return map.colliders.contains { collider in
            guard collider.kind == .hull || collider.kind == .interiorWall else { return false }
            return circleIntersects(
                shape: collider.shape,
                center: center,
                radius: radius,
                epsilon: map.configuration.walkabilityEpsilon
            )
        }
    }

    private func intersectsObstacle(center: CGPoint, radius: CGFloat) -> Bool {
        map.colliders.contains { collider in
            guard collider.kind == .furniture || collider.kind == .machinery else { return false }
            return circleIntersects(
                shape: collider.shape,
                center: center,
                radius: radius,
                epsilon: map.configuration.walkabilityEpsilon
            )
        }
    }
}

private func shapeContains(
    _ shape: ShipColliderShape,
    point: CGPoint,
    epsilon: CGFloat
) -> Bool {
    switch shape {
    case let .rectangle(rectangle):
        rectangle.insetBy(dx: -epsilon, dy: -epsilon).contains(point)
    case let .polygon(points):
        polygonContains(point, points: points)
            || polygonEdges(points).contains {
                squaredDistanceFromPoint(point, toSegmentFrom: $0.0, to: $0.1)
                    <= epsilon * epsilon
            }
    case let .edgeLoop(points):
        polygonContains(point, points: points)
            || polygonEdges(points).contains {
                squaredDistanceFromPoint(point, toSegmentFrom: $0.0, to: $0.1)
                    <= epsilon * epsilon
            }
    }
}

private func circleIntersects(
    shape: ShipColliderShape,
    center: CGPoint,
    radius: CGFloat,
    epsilon: CGFloat
) -> Bool {
    switch shape {
    case let .rectangle(rectangle):
        return circleIntersectsRectangle(
            center: center,
            radius: radius,
            rectangle: rectangle,
            epsilon: epsilon
        )

    case let .polygon(points):
        guard points.count >= 3 else { return false }
        if polygonContains(center, points: points) { return true }
        return polygonEdges(points).contains { edge in
            squaredDistanceFromPoint(center, toSegmentFrom: edge.0, to: edge.1)
                < max(0, radius - epsilon) * max(0, radius - epsilon)
        }

    case let .edgeLoop(points):
        guard points.count >= 2 else { return false }
        return polygonEdges(points).contains { edge in
            squaredDistanceFromPoint(center, toSegmentFrom: edge.0, to: edge.1)
                < max(0, radius - epsilon) * max(0, radius - epsilon)
        }
    }
}

private func circleIntersectsRectangle(
    center: CGPoint,
    radius: CGFloat,
    rectangle: CGRect,
    epsilon: CGFloat
) -> Bool {
    let rect = rectangle.standardized
    let closest = CGPoint(
        x: min(max(center.x, rect.minX), rect.maxX),
        y: min(max(center.y, rect.minY), rect.maxY)
    )
    let effectiveRadius = max(0, radius - epsilon)
    return squaredDistance(center, closest) < effectiveRadius * effectiveRadius
}

private func polygonEdges(_ points: [CGPoint]) -> [(CGPoint, CGPoint)] {
    guard let first = points.first else { return [] }
    var edges: [(CGPoint, CGPoint)] = []
    edges.reserveCapacity(points.count)
    var previous = first
    for point in points.dropFirst() {
        edges.append((previous, point))
        previous = point
    }
    edges.append((previous, first))
    return edges
}

private func polygonContains(_ point: CGPoint, points: [CGPoint]) -> Bool {
    var contains = false
    var previous = points[points.count - 1]
    for current in points {
        let intersectsY = (current.y > point.y) != (previous.y > point.y)
        if intersectsY {
            let xAtY = (previous.x - current.x) * (point.y - current.y)
                / (previous.y - current.y) + current.x
            if point.x < xAtY { contains.toggle() }
        }
        previous = current
    }
    return contains
}

private func squaredDistanceFromPoint(
    _ point: CGPoint,
    toSegmentFrom start: CGPoint,
    to end: CGPoint
) -> CGFloat {
    let dx = end.x - start.x
    let dy = end.y - start.y
    let lengthSquared = dx * dx + dy * dy
    guard lengthSquared > 0 else { return squaredDistance(point, start) }
    let projection = ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared
    let t = min(max(projection, 0), 1)
    return squaredDistance(point, CGPoint(x: start.x + t * dx, y: start.y + t * dy))
}

private func squaredDistance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
    let dx = lhs.x - rhs.x
    let dy = lhs.y - rhs.y
    return dx * dx + dy * dy
}
