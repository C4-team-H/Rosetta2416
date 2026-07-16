import SpriteKit

extension GameScene {
    /// Applies the existing analog joystick input as a physics velocity.
    func movePlayer() {
        guard sessionState.energy > 0 else {
            stopPlayerMovement()
            return
        }
        applyMovementVector(joystickVector, maximumSpeed: playerSpeed)
    }

    /// Keeps Apple Pencil tap-to-move while using the same collision-safe body.
    func movePlayerTowardTarget() {
        guard let target = pencilTarget else {
            stopPlayerMovement()
            return
        }
        guard sessionState.energy > 0 else {
            pencilTarget = nil
            hideTargetMarker()
            stopPlayerMovement()
            return
        }

        let dx = target.x - player.position.x
        let dy = target.y - player.position.y
        let distance = hypot(dx, dy)
        guard distance > arrivalThreshold else {
            pencilTarget = nil
            hideTargetMarker()
            stopPlayerMovement()
            return
        }

        let maximumSpeed = playerSpeed * pencilSpeedMultiplier
        let safeDelta = max(frameDeltaTime, 1.0 / 120.0)
        let arrivalLimitedSpeed = distance / CGFloat(safeDelta)
        applyMovementVector(
            CGPoint(x: dx / distance, y: dy / distance),
            maximumSpeed: min(maximumSpeed, arrivalLimitedSpeed)
        )
    }

    func stopPlayerMovement() {
        player?.physicsBody?.velocity = .zero
        player?.physicsBody?.angularVelocity = 0
    }

    private func applyMovementVector(_ input: CGPoint, maximumSpeed: CGFloat) {
        let magnitude = hypot(input.x, input.y)
        guard magnitude > 0, maximumSpeed > 0 else {
            stopPlayerMovement()
            return
        }

        // Preserve analog magnitude below one and clamp diagonals above one.
        let scale = magnitude > 1 ? 1 / magnitude : 1
        player.physicsBody?.velocity = CGVector(
            dx: input.x * scale * maximumSpeed,
            dy: input.y * scale * maximumSpeed
        )
    }
}
