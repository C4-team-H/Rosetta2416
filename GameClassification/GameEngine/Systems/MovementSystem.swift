import SpriteKit

struct MovementSystem {
    let collisionSystem: CollisionSystem

    func move(
        from position: CGPoint,
        direction input: CGPoint,
        speed: CGFloat,
        deltaTime: TimeInterval,
        footprint: CollisionFootprint,
        target: CGPoint? = nil,
        arrivalThreshold: CGFloat = 0
    ) -> MovementResult {
        let magnitude = hypot(input.x, input.y)
        let safeDelta = CGFloat(min(max(deltaTime, 0), 0.25))
        guard magnitude > 0, speed > 0, safeDelta > 0 else {
            return .stationary(at: position)
        }

        let inputScale = magnitude > 1 ? 1 / magnitude : 1
        var distance = speed * safeDelta
        if let target {
            let remainingDistance = hypot(target.x - position.x, target.y - position.y)
            if remainingDistance <= arrivalThreshold {
                return .stationary(at: position, reachedTarget: true)
            }
            distance = min(distance, remainingDistance)
        }

        let delta = CGVector(
            dx: input.x * inputScale * distance,
            dy: input.y * inputScale * distance
        )
        let collisionResult = collisionSystem.resolveMovement(
            from: position,
            delta: delta,
            footprint: footprint
        )
        let reachedTarget = target.map {
            hypot($0.x - collisionResult.finalPosition.x, $0.y - collisionResult.finalPosition.y)
                <= arrivalThreshold
        } ?? false

        return MovementResult(
            finalPosition: collisionResult.finalPosition,
            appliedDisplacement: collisionResult.appliedDisplacement,
            blockedAxes: collisionResult.blockedAxes,
            blockingReason: collisionResult.blockingReason,
            reachedTarget: reachedTarget
        )
    }
}

extension GameScene {
    @discardableResult
    func movePlayer() -> MovementResult {
        guard sessionState.energy > 0 || debugSettings.allowsCollisionTesting else {
            stopPlayerMovement()
            return lastMovementResult
        }
        let result = movementSystem.move(
            from: player.position,
            direction: joystickVector,
            speed: playerSpeed,
            deltaTime: frameDeltaTime,
            footprint: player.collisionFootprint
        )
        applyMovementResult(result)
        return result
    }

    @discardableResult
    func movePlayerTowardTarget() -> MovementResult {
        guard let target = pencilTarget else {
            stopPlayerMovement()
            return lastMovementResult
        }
        guard sessionState.energy > 0 || debugSettings.allowsCollisionTesting else {
            clearPencilTarget()
            stopPlayerMovement()
            return lastMovementResult
        }

        let dx = target.x - player.position.x
        let dy = target.y - player.position.y
        let distance = hypot(dx, dy)
        guard distance > arrivalThreshold else {
            clearPencilTarget()
            let result = MovementResult.stationary(at: player.position, reachedTarget: true)
            applyMovementResult(result)
            return result
        }

        let result = movementSystem.move(
            from: player.position,
            direction: CGPoint(x: dx / distance, y: dy / distance),
            speed: playerSpeed * pencilSpeedMultiplier,
            deltaTime: frameDeltaTime,
            footprint: player.collisionFootprint,
            target: target,
            arrivalThreshold: arrivalThreshold
        )
        applyMovementResult(result)

        if result.reachedTarget {
            clearPencilTarget()
        } else if frameDeltaTime > 0, !result.isMoving {
            pencilBlockedFrameCount += 1
            if pencilBlockedFrameCount >= Self.maximumBlockedPencilFrames {
                rejectCurrentPencilTarget(reason: result.blockingReason ?? .invalid)
            }
        } else {
            pencilBlockedFrameCount = 0
        }
        return result
    }

    func stopPlayerMovement() {
        player?.physicsBody?.velocity = .zero
        player?.physicsBody?.angularVelocity = 0
        if let player {
            lastMovementResult = .stationary(at: player.position)
        }
    }

    func applyMovementResult(_ result: MovementResult) {
        player.physicsBody?.velocity = .zero
        player.physicsBody?.angularVelocity = 0
        player.position = result.finalPosition
        lastMovementResult = result
        if walkabilitySystem.isWalkable(
            position: result.finalPosition,
            footprint: player.collisionFootprint
        ).isWalkable {
            lastValidPlayerPosition = result.finalPosition
        }
        synchronizeCandleLightWithPlayer()
    }
}
