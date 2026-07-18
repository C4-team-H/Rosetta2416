import CoreGraphics
import Foundation

enum MapGeometryValidationSeverity: String, Codable, Sendable {
    case error
    case warning
}

struct MapGeometryValidationIssue: Identifiable, Equatable, Sendable {
    let id: String
    let severity: MapGeometryValidationSeverity
    let message: String
    let elementIDs: [MapElementID]

    init(
        severity: MapGeometryValidationSeverity,
        message: String,
        elementIDs: [MapElementID] = []
    ) {
        self.severity = severity
        self.message = message
        self.elementIDs = elementIDs
        id = "\(severity.rawValue):\(elementIDs.map(\.id).joined(separator: ",")):\(message)"
    }
}

struct MapGeometryValidationResult: Equatable, Sendable {
    var errors: [MapGeometryValidationIssue]
    var warnings: [MapGeometryValidationIssue]

    static let empty = MapGeometryValidationResult(errors: [], warnings: [])
    var isValid: Bool { errors.isEmpty }
}

struct MapGeometryValidator {
    func structuralIssues(in configuration: MapGeometryConfiguration) -> [MapGeometryValidationIssue] {
        var issues: [MapGeometryValidationIssue] = []
        guard configuration.schemaVersion == MapGeometryConfiguration.currentSchemaVersion else {
            issues.append(.init(severity: .error, message: "Unsupported schema version \(configuration.schemaVersion)"))
            return issues
        }
        if !configuration.worldSize.isValid {
            issues.append(.init(severity: .error, message: "World size must be finite and positive"))
        }
        if !configuration.playerFootprint.centerOffset.isFinite
            || !configuration.playerFootprint.width.isFinite
            || !configuration.playerFootprint.height.isFinite
            || !configuration.playerFootprint.obstacleRadius.isFinite
            || configuration.playerFootprint.width <= 0
            || configuration.playerFootprint.height <= 0
            || configuration.playerFootprint.obstacleRadius <= 0 {
            issues.append(.init(severity: .error, message: "Player footprint is invalid"))
        }

        let groupedIDs = Dictionary(grouping: configuration.allElements, by: { $0.id.rawValue })
        for (id, matches) in groupedIDs where matches.count > 1 {
            issues.append(.init(
                severity: .error,
                message: "Duplicate map ID: \(id)",
                elementIDs: matches.map(\.id)
            ))
        }

        for element in configuration.allElements {
            if !element.freeformPointSets.allSatisfy({ points in
                points.count >= 3 && points.allSatisfy(\.isFinite)
            }) {
                issues.append(.init(
                    severity: .error,
                    message: "\(element.name) has invalid freeform vertices",
                    elementIDs: [element.id]
                ))
                continue
            }
            if case let .wall(wall) = element,
               !wall.rotationRadians.isFinite {
                issues.append(.init(
                    severity: .error,
                    message: "\(element.name) has an invalid rotation",
                    elementIDs: [element.id]
                ))
                continue
            }
            if let frame = element.worldFrame,
               !frameIsValid(frame) {
                issues.append(.init(
                    severity: .error,
                    message: "\(element.name) has an invalid or non-positive frame",
                    elementIDs: [element.id]
                ))
            } else if element.worldFrame == nil,
                      (!element.worldPosition.x.isFinite || !element.worldPosition.y.isFinite) {
                issues.append(.init(
                    severity: .error,
                    message: "\(element.name) has an invalid position",
                    elementIDs: [element.id]
                ))
            }
        }
        return issues
    }

    func validate(
        _ configuration: MapGeometryConfiguration,
        includeReachability: Bool = true
    ) -> MapGeometryValidationResult {
        var errors = structuralIssues(in: configuration)
        var warnings: [MapGeometryValidationIssue] = []
        guard errors.isEmpty else { return MapGeometryValidationResult(errors: errors, warnings: warnings) }

        let worldFrame = CGRect(origin: .zero, size: configuration.worldSize.cgSize)
        for element in configuration.allElements {
            let bounds: CGRect
            if case let .wall(wall) = element {
                bounds = wall.rotatedBounds
            } else {
                bounds = element.worldFrame ?? CGRect(origin: element.worldPosition, size: .zero)
            }
            if !worldFrame.intersects(bounds.insetBy(dx: -0.01, dy: -0.01)) {
                warnings.append(.init(
                    severity: .warning,
                    message: "\(element.name) is outside the world bounds",
                    elementIDs: [element.id]
                ))
            }
        }

        for firstIndex in configuration.rooms.indices {
            for secondIndex in configuration.rooms.indices where secondIndex > firstIndex {
                let first = configuration.rooms[firstIndex]
                let second = configuration.rooms[secondIndex]
                if first.frame.cgRect.intersection(second.frame.cgRect).area > configuration.walkabilityEpsilon * configuration.walkabilityEpsilon {
                    errors.append(.init(
                        severity: .error,
                        message: "\(first.name) overlaps \(second.name)",
                        elementIDs: [
                            MapElementID(category: .room, rawValue: first.id),
                            MapElementID(category: .room, rawValue: second.id)
                        ]
                    ))
                }
            }
        }

        let clearance = max(
            configuration.playerFootprint.width,
            configuration.playerFootprint.height
        ) + configuration.walkabilityEpsilon * 2
        for door in configuration.doorways where door.isEnabled {
            let doorID = MapElementID(category: .doorway, rawValue: door.id)
            let frame = door.frame.cgRect
            if max(frame.width, frame.height) < clearance {
                errors.append(.init(
                    severity: .error,
                    message: "\(door.name) is narrower than player clearance",
                    elementIDs: [doorID]
                ))
            }
            let seam = frame.insetBy(dx: -configuration.walkabilityEpsilon * 3, dy: -configuration.walkabilityEpsilon * 3)
            let connectsRoom = configuration.rooms.contains { room in
                room.roomID == door.roomID && room.frame.cgRect.intersects(seam)
            }
            let connectsCorridor = configuration.corridors.contains { $0.isWalkable && $0.frame.cgRect.intersects(seam) }
            if !connectsRoom || !connectsCorridor {
                errors.append(.init(
                    severity: .error,
                    message: "\(door.name) does not bridge its room and a corridor",
                    elementIDs: [doorID]
                ))
            }
            let blockingWalls = configuration.walls.filter { wall in
                wall.isEnabled && wall.rotatedBounds.insetBy(dx: 0.5, dy: 0.5).intersects(frame.insetBy(dx: 0.5, dy: 0.5))
            }
            if !blockingWalls.isEmpty {
                errors.append(.init(
                    severity: .error,
                    message: "\(door.name) is blocked by \(blockingWalls.map(\.name).joined(separator: ", "))",
                    elementIDs: [doorID] + blockingWalls.map { MapElementID(category: .wall, rawValue: $0.id) }
                ))
            }
        }

        let runtimeMap = GameMapLayout.makeRuntimeMap(from: configuration)
        let openDoors = Dictionary(uniqueKeysWithValues: DoorID.allCases.map { ($0, DoorState.open) })
        let walkability = WalkabilitySystem(map: runtimeMap, doorStates: openDoors)
        let footprint = configuration.playerFootprint.runtimeValue

        for spawn in configuration.spawnPoints {
            guard !walkability.isWalkable(position: spawn.position.cgPoint, footprint: footprint).isWalkable else { continue }
            errors.append(.init(
                severity: .error,
                message: "\(spawn.name) is not walkable",
                elementIDs: [MapElementID(category: .spawnPoint, rawValue: spawn.id)]
            ))
        }
        for checkpoint in configuration.checkpoints {
            guard !walkability.isWalkable(position: checkpoint.position.cgPoint, footprint: footprint).isWalkable else { continue }
            errors.append(.init(
                severity: .error,
                message: "\(checkpoint.name) checkpoint is not walkable",
                elementIDs: [MapElementID(category: .checkpoint, rawValue: checkpoint.id)]
            ))
        }

        let blockingWalls = configuration.walls.filter(\.isEnabled)
        let blockerFrames = configuration.objects.filter { $0.isEnabled && $0.type == .obstacle }.map(\.frame)
        for station in configuration.stations where station.isEnabled {
            let category: MapElementCategory = station.kind == .food ? .foodStation : .missionStation
            if station.kind == .mission && station.interactionID == nil {
                warnings.append(.init(
                    severity: .warning,
                    message: "\(station.name) is not bound to a story objective",
                    elementIDs: [MapElementID(category: category, rawValue: station.id)]
                ))
            }
            if blockingWalls.contains(where: { $0.contains(station.position.cgPoint) })
                || blockerFrames.contains(where: { $0.contains(station.position.cgPoint) }) {
                warnings.append(.init(
                    severity: .warning,
                    message: "\(station.name) is inside a blocking object or wall",
                    elementIDs: [MapElementID(category: category, rawValue: station.id)]
                ))
            }
        }

        if includeReachability,
           let sleepingSpawn = configuration.spawnPoints.first(where: { $0.roomID == .sleepingRoom }) {
            let reachableOpen = reachableGridPoints(
                from: sleepingSpawn.position.cgPoint,
                system: walkability,
                footprint: footprint,
                worldSize: configuration.worldSize.cgSize,
                step: 10
            )
            for room in RoomID.allCases {
                guard let destination = configuration.spawnPoints.first(where: { $0.roomID == room })?.position.cgPoint else {
                    errors.append(.init(severity: .error, message: "Missing spawn for \(room.displayName)"))
                    continue
                }
                if !containsReachable(destination, in: reachableOpen, step: 10) {
                    errors.append(.init(
                        severity: .error,
                        message: "\(room.displayName) is unreachable with all doors open",
                        elementIDs: [MapElementID(category: .room, rawValue: "room-\(room.rawValue)")]
                    ))
                }
            }

            let initialStates = Dictionary(uniqueKeysWithValues: DoorID.allCases.map { id in
                let state = configuration.doorways.first(where: { $0.doorID == id })?.defaultState ?? .closed
                return (id, state)
            })
            let initialSystem = WalkabilitySystem(map: runtimeMap, doorStates: initialStates)
            let reachableInitial = reachableGridPoints(
                from: sleepingSpawn.position.cgPoint,
                system: initialSystem,
                footprint: footprint,
                worldSize: configuration.worldSize.cgSize,
                step: 10
            )
            for lockedRoom in [RoomID.engine, .storage, .cockpit] {
                if let destination = configuration.spawnPoints.first(where: { $0.roomID == lockedRoom })?.position.cgPoint,
                   containsReachable(destination, in: reachableInitial, step: 10) {
                    errors.append(.init(
                        severity: .error,
                        message: "\(lockedRoom.displayName) is reachable while story-locked"
                    ))
                }
            }
        }

        return MapGeometryValidationResult(errors: errors, warnings: warnings)
    }

    private struct GridPoint: Hashable {
        let x: Int
        let y: Int
    }

    private func reachableGridPoints(
        from start: CGPoint,
        system: WalkabilitySystem,
        footprint: CollisionFootprint,
        worldSize: CGSize,
        step: CGFloat
    ) -> Set<GridPoint> {
        let startPoint = GridPoint(x: Int((start.x / step).rounded()), y: Int((start.y / step).rounded()))
        var queue = [startPoint]
        var visited: Set<GridPoint> = [startPoint]
        var reachable: Set<GridPoint> = [startPoint]
        var cursor = 0
        let directions = [(1, 0), (-1, 0), (0, 1), (0, -1)]

        while cursor < queue.count {
            let current = queue[cursor]
            cursor += 1
            for direction in directions {
                let next = GridPoint(x: current.x + direction.0, y: current.y + direction.1)
                guard visited.insert(next).inserted else { continue }
                let point = CGPoint(x: CGFloat(next.x) * step, y: CGFloat(next.y) * step)
                guard point.x >= 0, point.y >= 0,
                      point.x <= worldSize.width, point.y <= worldSize.height,
                      system.isWalkable(position: point, footprint: footprint).isWalkable else { continue }
                reachable.insert(next)
                queue.append(next)
            }
        }
        return reachable
    }

    private func containsReachable(_ point: CGPoint, in points: Set<GridPoint>, step: CGFloat) -> Bool {
        let x = Int((point.x / step).rounded())
        let y = Int((point.y / step).rounded())
        for dx in -1...1 where points.contains(GridPoint(x: x + dx, y: y)) { return true }
        for dy in -1...1 where points.contains(GridPoint(x: x, y: y + dy)) { return true }
        return false
    }

    private func frameIsValid(_ frame: CGRect) -> Bool {
        !frame.isNull && !frame.isInfinite
            && frame.origin.x.isFinite && frame.origin.y.isFinite
            && frame.width.isFinite && frame.height.isFinite
            && frame.width > 0 && frame.height > 0
    }
}

private extension CGRect {
    var area: CGFloat { isNull ? 0 : max(0, width) * max(0, height) }
}
