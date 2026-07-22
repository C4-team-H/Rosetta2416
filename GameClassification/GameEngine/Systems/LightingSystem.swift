import AudioToolbox
import SpriteKit

@MainActor
final class LightingSystem {
    private var appliedState: ShipPowerState?

    func apply(_ powerState: ShipPowerState, to scene: GameScene) {
        guard appliedState != powerState else { return }
        appliedState = powerState

        switch powerState {
        case .off:
            scene.candleLight?.alpha = 1
            scene.gridContainer?.alpha = 1
            scene.backgroundColor = SKColor(red: 0.12, green: 0.14, blue: 0.2, alpha: 1)
        case .basicPower:
            // Engine 10% reward: room lighting replaces the flashlight.
            scene.candleLight?.alpha = 0
            scene.gridContainer?.alpha = 0.28
            scene.backgroundColor = SKColor(red: 0.42, green: 0.48, blue: 0.58, alpha: 1)
        case .disrupted:
            // Engine 40% disruption: emergency darkness and flashlight return.
            scene.candleLight?.alpha = 1
            scene.gridContainer?.alpha = 1
            scene.backgroundColor = SKColor(red: 0.10, green: 0.11, blue: 0.16, alpha: 1)
        case .fullyRestored:
            scene.candleLight?.alpha = 0
            scene.gridContainer?.alpha = 0.22
            scene.backgroundColor = SKColor(red: 0.46, green: 0.53, blue: 0.64, alpha: 1)
        }
    }

    func transition(to powerState: ShipPowerState, in scene: GameScene) {
        appliedState = nil
        switch powerState {
        case .basicPower:
            playPlaceholderSound(1104)
            flash(in: scene, color: .white, duration: 0.45)
        case .disrupted:
            playPlaceholderSound(1053)
            flash(in: scene, color: .red, duration: 0.7)
            shake(scene.cameraNode)
        case .fullyRestored:
            break
        case .off:
            break
        }
        apply(powerState, to: scene)
    }

    func playVictory(in scene: GameScene) {
        activateCockpitDisplays(in: scene)
        playPlaceholderSound(1025)
        flash(in: scene, color: .green, duration: 1.1)
    }

    func playAdvancedToolsAcquired(in scene: GameScene) {
        playPlaceholderSound(1103)
        flash(in: scene, color: .yellow, duration: 0.55)
        guard let node = scene.stationNodes["storage-calibration-unit"] else { return }
        node.run(.sequence([
            .group([.scale(to: 1.3, duration: 0.2), .fadeAlpha(to: 1, duration: 0.2)]),
            .scale(to: 1, duration: 0.35)
        ]), withKey: "advancedToolsAcquired")
    }

    private func flash(in scene: GameScene, color: SKColor, duration: TimeInterval) {
        let overlay = SKSpriteNode(color: color, size: scene.size)
        overlay.name = "lightingFlashOverlay"
        overlay.alpha = 0
        overlay.zPosition = 24
        scene.cameraNode.addChild(overlay)
        overlay.run(.sequence([
            .fadeAlpha(to: 0.75, duration: duration * 0.2),
            .fadeOut(withDuration: duration * 0.8),
            .removeFromParent()
        ]))
    }

    private func shake(_ camera: SKCameraNode) {
        let movements: [SKAction] = [
            .moveBy(x: 8, y: 0, duration: 0.04),
            .moveBy(x: -16, y: 4, duration: 0.06),
            .moveBy(x: 12, y: -8, duration: 0.06),
            .moveBy(x: -4, y: 4, duration: 0.05)
        ]
        camera.run(.sequence(movements), withKey: "powerDisruptionShake")
    }

    private func activateCockpitDisplays(in scene: GameScene) {
        guard scene.childNode(withName: "cockpitDisplayGlow") == nil else { return }
        let display = SKShapeNode(
            rectOf: GameMapLayout.scaled(CGSize(width: 260, height: 120)),
            cornerRadius: GameMapLayout.scaled(18)
        )
        display.name = "cockpitDisplayGlow"
        display.position = roomCenter(.cockpit)
        display.fillColor = .cyan.withAlphaComponent(0.22)
        display.strokeColor = .cyan
        display.glowWidth = GameMapLayout.scaled(12)
        display.zPosition = 0.5
        scene.addChild(display)
    }

    private func roomCenter(_ roomID: RoomID) -> CGPoint {
        guard let frame = GameMapLayout.rooms.first(where: { $0.id == roomID })?.worldFrame else {
            return CGPoint(x: GameMapLayout.worldSize.width / 2, y: GameMapLayout.worldSize.height / 2)
        }
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    private func playPlaceholderSound(_ soundID: SystemSoundID) {
        AudioServicesPlaySystemSound(soundID)
    }
}
