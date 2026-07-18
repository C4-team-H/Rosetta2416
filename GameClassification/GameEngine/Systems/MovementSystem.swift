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
            footprint: player.navigationFootprint
        )
        applyMovementIntent(result)
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
            stopPlayerMovement()
            lastMovementResult = result
            return result
        }

        let result = movementSystem.move(
            from: player.position,
            direction: CGPoint(x: dx / distance, y: dy / distance),
            speed: playerSpeed * pencilSpeedMultiplier,
            deltaTime: frameDeltaTime,
            footprint: player.navigationFootprint,
            target: target,
            arrivalThreshold: arrivalThreshold
        )
        applyMovementIntent(result)

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
        player?.stopMovement()
    }

    func applyMovementIntent(_ result: MovementResult) {
        let safeDelta = CGFloat(min(max(frameDeltaTime, 0), 0.25))
        guard safeDelta > 0, result.isMoving else {
            player.stopMovement()
            return
        }
        player.setMovementVelocity(CGVector(
            dx: result.appliedDisplacement.dx / safeDelta,
            dy: result.appliedDisplacement.dy / safeDelta
        ))
    }

    func recordPhysicsMovement() {
        guard let player else { return }
        let start = physicsFrameStartPosition ?? player.position
        var displacement = CGVector(
            dx: player.position.x - start.x,
            dy: player.position.y - start.y
        )
        let walkability = walkabilitySystem.isWalkable(
            position: player.position,
            footprint: player.navigationFootprint
        )
        if !walkability.isWalkable {
            let correctedMovement = collisionSystem.resolveMovement(
                from: start,
                delta: displacement,
                footprint: player.navigationFootprint
            )
            player.position = correctedMovement.finalPosition
            player.stopMovement()
            displacement = correctedMovement.appliedDisplacement
        }
        var reachedTarget = false
        if let target = pencilTarget,
           hypot(target.x - player.position.x, target.y - player.position.y) <= arrivalThreshold {
            reachedTarget = true
            clearPencilTarget()
            player.stopMovement()
        }
        lastMovementResult = MovementResult(
            finalPosition: player.position,
            appliedDisplacement: displacement,
            blockedAxes: [],
            blockingReason: nil,
            reachedTarget: reachedTarget
        )
        lastValidPlayerPosition = player.position
        player.synchronizeInteractionSensor()
    }
}
