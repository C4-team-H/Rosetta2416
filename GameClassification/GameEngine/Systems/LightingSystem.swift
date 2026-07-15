import AudioToolbox
import SpriteKit

@MainActor
final class LightingSystem {
    private var appliedState: ShipPowerState?

    func apply(_ powerState: ShipPowerState, to scene: GameScene) {
        guard appliedState != powerState else { return }
        appliedState = powerState

        switch powerState {
        case .emergency:
            scene.candleLight?.alpha = 1
            scene.backgroundColor = SKColor(red: 0.12, green: 0.14, blue: 0.2, alpha: 1)
        case .basicPower:
            scene.candleLight?.alpha = 0.18
            scene.backgroundColor = SKColor(red: 0.20, green: 0.24, blue: 0.32, alpha: 1)
        case .disrupted:
            scene.candleLight?.alpha = 1
            scene.backgroundColor = SKColor(red: 0.10, green: 0.11, blue: 0.16, alpha: 1)
        case .fullyRestored:
            scene.candleLight?.alpha = 0
            scene.backgroundColor = SKColor(red: 0.24, green: 0.29, blue: 0.38, alpha: 1)
            activateEngineGlow(in: scene)
            activateEngineParticles(in: scene)
            activateMachinery(in: scene)
            activateCockpitDisplays(in: scene)
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
            playPlaceholderSound(1025)
            flash(in: scene, color: .cyan, duration: 0.8)
        case .emergency:
            break
        }
        apply(powerState, to: scene)
    }

    func playVictory(in scene: GameScene) {
        playPlaceholderSound(1025)
        flash(in: scene, color: .green, duration: 1.1)
    }

    private func flash(in scene: GameScene, color: SKColor, duration: TimeInterval) {
        let overlay = SKSpriteNode(color: color, size: scene.size)
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

    private func activateEngineGlow(in scene: GameScene) {
        guard scene.childNode(withName: "engineRestoredGlow") == nil else { return }
        let glow = SKShapeNode(circleOfRadius: 150)
        glow.name = "engineRestoredGlow"
        glow.position = CGPoint(x: 1_000, y: 1_000)
        glow.fillColor = .cyan.withAlphaComponent(0.12)
        glow.strokeColor = .cyan
        glow.glowWidth = 18
        glow.zPosition = 0.5
        glow.run(.repeatForever(.sequence([
            .scale(to: 1.08, duration: 0.8),
            .scale(to: 0.94, duration: 0.8)
        ])))
        scene.addChild(glow)
    }

    private func activateCockpitDisplays(in scene: GameScene) {
        guard scene.childNode(withName: "cockpitDisplayGlow") == nil else { return }
        let display = SKShapeNode(rectOf: CGSize(width: 260, height: 120), cornerRadius: 18)
        display.name = "cockpitDisplayGlow"
        display.position = CGPoint(x: 1_625, y: 1_680)
        display.fillColor = .cyan.withAlphaComponent(0.22)
        display.strokeColor = .cyan
        display.glowWidth = 12
        display.zPosition = 0.5
        scene.addChild(display)
    }

    private func activateEngineParticles(in scene: GameScene) {
        guard scene.childNode(withName: "engineRestoredParticles") == nil else { return }
        let particles = SKEmitterNode()
        particles.name = "engineRestoredParticles"
        particles.position = CGPoint(x: 1_000, y: 1_000)
        particles.particleBirthRate = 12
        particles.particleLifetime = 1.8
        particles.particlePositionRange = CGVector(dx: 220, dy: 220)
        particles.particleSpeed = 18
        particles.particleSpeedRange = 10
        particles.emissionAngleRange = .pi * 2
        particles.particleScale = 0.08
        particles.particleScaleRange = 0.04
        particles.particleAlpha = 0.65
        particles.particleAlphaSpeed = -0.32
        particles.particleColor = .cyan
        particles.particleColorBlendFactor = 1
        particles.zPosition = 1
        scene.addChild(particles)
    }

    private func activateMachinery(in scene: GameScene) {
        guard scene.childNode(withName: "engineMachinery") == nil else { return }
        let machinery = SKNode()
        machinery.name = "engineMachinery"
        machinery.position = CGPoint(x: 1_000, y: 1_000)
        machinery.zPosition = 1
        for offset in [CGFloat(-110), CGFloat(110)] {
            let rotor = SKShapeNode(circleOfRadius: 34)
            rotor.position = CGPoint(x: offset, y: 0)
            rotor.strokeColor = .cyan
            rotor.lineWidth = 6
            rotor.fillColor = .clear
            let spoke = SKShapeNode(rectOf: CGSize(width: 58, height: 5), cornerRadius: 2)
            spoke.fillColor = .cyan
            spoke.strokeColor = .clear
            rotor.addChild(spoke)
            rotor.run(.repeatForever(.rotate(byAngle: offset < 0 ? .pi * 2 : -.pi * 2, duration: 1.2)))
            machinery.addChild(rotor)
        }
        scene.addChild(machinery)
    }

    private func playPlaceholderSound(_ soundID: SystemSoundID) {
        AudioServicesPlaySystemSound(soundID)
    }
}
