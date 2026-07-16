import CoreGraphics
import Foundation

struct BlockedMovementAxes: OptionSet, Equatable {
    let rawValue: UInt8

    static let horizontal = BlockedMovementAxes(rawValue: 1 << 0)
    static let vertical = BlockedMovementAxes(rawValue: 1 << 1)
}

struct MovementResult: Equatable {
    let finalPosition: CGPoint
    let appliedDisplacement: CGVector
    let blockedAxes: BlockedMovementAxes
    let blockingReason: BlockedAreaType?
    let reachedTarget: Bool

    var isMoving: Bool {
        hypot(appliedDisplacement.dx, appliedDisplacement.dy) > 0
    }

    static func stationary(
        at position: CGPoint,
        reason: BlockedAreaType? = nil,
        reachedTarget: Bool = false
    ) -> MovementResult {
        MovementResult(
            finalPosition: position,
            appliedDisplacement: .zero,
            blockedAxes: [],
            blockingReason: reason,
            reachedTarget: reachedTarget
        )
    }
}

struct CollisionSystem {
    let walkabilitySystem: WalkabilitySystem

    func resolveMovement(
        from start: CGPoint,
        delta: CGVector,
        footprint: CollisionFootprint
    ) -> MovementResult {
        resolveMovement(
            from: start,
            delta: delta,
            footprint: footprint,
            doorStates: walkabilitySystem.doorStates
        )
    }

    func resolveMovement(
        from start: CGPoint,
        delta: CGVector,
        footprint: CollisionFootprint,
        doorStates: [DoorID: DoorState]
    ) -> MovementResult {
        guard delta.dx.isFinite, delta.dy.isFinite else {
            return .stationary(at: start, reason: .invalid)
        }

        let distance = hypot(delta.dx, delta.dy)
        guard distance > 0 else { return .stationary(at: start) }

        let maximumSubstep = max(
            footprint.radius / 2,
            walkabilitySystem.map.configuration.walkabilityEpsilon
        )
        let stepCount = max(1, Int(ceil(distance / maximumSubstep)))
        let step = CGVector(
            dx: delta.dx / CGFloat(stepCount),
            dy: delta.dy / CGFloat(stepCount)
        )

        var position = start
        var blockedAxes: BlockedMovementAxes = []
        var blockingReason: BlockedAreaType?

        for _ in 0..<stepCount {
            let fullCandidate = CGPoint(x: position.x + step.dx, y: position.y + step.dy)
            let fullResult = walkabilitySystem.isWalkable(
                position: fullCandidate,
                footprint: footprint,
                doorStates: doorStates
            )
            if fullResult.isWalkable {
                position = fullCandidate
                continue
            }

            blockingReason = blockingReason ?? fullResult.blockedReason

            if abs(step.dx) > 0 {
                let horizontalCandidate = CGPoint(x: position.x + step.dx, y: position.y)
                let horizontalResult = walkabilitySystem.isWalkable(
                    position: horizontalCandidate,
                    footprint: footprint,
                    doorStates: doorStates
                )
                if horizontalResult.isWalkable {
                    position = horizontalCandidate
                    blockedAxes.insert(.vertical)
                    continue
                }
                blockingReason = blockingReason ?? horizontalResult.blockedReason
            }

            if abs(step.dy) > 0 {
                let verticalCandidate = CGPoint(x: position.x, y: position.y + step.dy)
                let verticalResult = walkabilitySystem.isWalkable(
                    position: verticalCandidate,
                    footprint: footprint,
                    doorStates: doorStates
                )
                if verticalResult.isWalkable {
                    position = verticalCandidate
                    blockedAxes.insert(.horizontal)
                    continue
                }
                blockingReason = blockingReason ?? verticalResult.blockedReason
            }

            if abs(step.dx) > 0 { blockedAxes.insert(.horizontal) }
            if abs(step.dy) > 0 { blockedAxes.insert(.vertical) }
        }

        return MovementResult(
            finalPosition: position,
            appliedDisplacement: CGVector(dx: position.x - start.x, dy: position.y - start.y),
            blockedAxes: blockedAxes,
            blockingReason: blockingReason,
            reachedTarget: false
        )
    }
}
