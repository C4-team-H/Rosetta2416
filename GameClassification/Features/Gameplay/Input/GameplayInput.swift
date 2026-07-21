//
//  GameScene+Touch.swift
//  GameClassification
//
//  Created by Muhammad Muthi' Nuritzan on 14/07/26.
//

import SpriteKit

// Extension ini khusus menangani sistem pendeteksian sentuhan layar (Touch & Apple Pencil).
extension GameScene {
    
    /// Dipanggil saat jari atau Apple Pencil pertama kali menyentuh layar.
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !tacticalMapViewModel.isMapPresented else { return }
        guard sessionState.phase == .playing else { return }
        guard !debugSettings.isEditingGameplaySuspended else { return }
        guard !sessionState.showLowEnergyAlert else { return }
        guard sessionState.currentDialogue == nil else { return }

        for touch in touches {
            let touchLocation = touch.location(in: self)
            let cameraTouchLocation = self.convert(touchLocation, to: cameraNode)
            
            // 1. Deteksi klik pada tombol interaktif (di bawah cameraNode)
            let nodesAtCameraPoint = cameraNode.nodes(at: cameraTouchLocation)
            for node in nodesAtCameraPoint {
                if node.name == "drawButton" {
                    AudioManager.shared.playButtonSound()
                    requestActiveStationInteraction()
                    return
                } else if node.name == "foodDrawButton" {
                    AudioManager.shared.playButtonSound()
                    requestFoodInteraction()
                    return
                } else if node.name == "albumButton" {
                    AudioManager.shared.playButtonSound()
                    requestAlbumInteraction()
                    return
                }
            }
            
            // 2. Deteksi input dari Apple Pencil (Pointer navigation)
            // Mendukung .pencil (Apple Pencil 2/Pro/USB-C) dan .stylus (Apple Pencil 1)
            if touch.type == .pencil || touch.type == .stylus {
                pencilTouch = touch
                setPencilTarget(touchLocation)
                updatePencilSpeedMultiplier(from: touch)
                continue
            }
            
            // 3. Deteksi input dari jari biasa untuk mengendalikan Joystick analog (di bawah cameraNode)
            if joystickBase.contains(cameraTouchLocation) {
                isJoystickActive = true
                joystickActiveTouch = touch
                updateJoystickKnob(touchLocation: cameraTouchLocation)
                break
            }
        }
    }
    
    /// Dipanggil saat jari atau Apple Pencil bergeser di atas layar.
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !tacticalMapViewModel.isMapPresented else { return }
        guard sessionState.phase == .playing else { return }
        guard !debugSettings.isEditingGameplaySuspended else { return }
        guard !sessionState.showLowEnergyAlert else { return }
        guard sessionState.currentDialogue == nil else { return }

        // Geser Apple Pencil -> Pindahkan titik koordinat target bergerak
        if let activePencil = pencilTouch, touches.contains(activePencil) {
            let loc = activePencil.location(in: self)
            setPencilTarget(loc)
            updatePencilSpeedMultiplier(from: activePencil)
            return
        }
        
        // Geser jari pada Joystick -> Update arah joystickVector
        guard isJoystickActive, let activeTouch = joystickActiveTouch else { return }
        if touches.contains(activeTouch) {
            let touchLocation = activeTouch.location(in: self)
            let cameraTouchLocation = self.convert(touchLocation, to: cameraNode)
            updateJoystickKnob(touchLocation: cameraTouchLocation)
        }
    }
    
    /// Dipanggil saat jari atau Apple Pencil diangkat dari layar.
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Apple Pencil diangkat -> Hentikan pencatatan sentuhan,
        // namun pertahankan target koordinat terakhir agar karakter tetap berjalan ke sana sampai sampai.
        if let activePencil = pencilTouch, touches.contains(activePencil) {
            pencilTouch = nil
            pencilSpeedMultiplier = 1.0
            return
        }
        
        // Jari joystick diangkat -> Lepas joystick dan setel kembali ke tengah
        guard let activeTouch = joystickActiveTouch else { return }
        if touches.contains(activeTouch) {
            resetJoystick()
        }
    }
    
    /// Dipanggil ketika sentuhan terinterupsi (misalnya ada notifikasi sistem masuk).
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if pencilTouch != nil {
            pencilTouch = nil
            pencilSpeedMultiplier = 1.0
            clearPencilTarget()
        }
        resetJoystick()
    }
    
    /// Mengonversi tingkat tekanan (pressure) Apple Pencil menjadi pengali kecepatan (multiplier).
    /// Goresan ringan = melambat (0.5x kecepatan), tekanan penuh = meluncur cepat (1.5x kecepatan).
    /// Perangkat simulator (yang tidak memiliki force sensor) akan otomatis bernilai 1.0x.
    func updatePencilSpeedMultiplier(from touch: UITouch) {
        let maxForce = touch.maximumPossibleForce
        guard maxForce > 0 else { pencilSpeedMultiplier = 1.0; return }
        let ratio = min(max(touch.force / maxForce, 0.0), 1.0)
        pencilSpeedMultiplier = 0.5 + ratio * 1.0 // rentang 0.5x sampai 1.5x
    }
    
    /// Memperbarui posisi tombol joystick (knob) relatif terhadap pusat alasnya.
    /// Membatasi pergeseran agar knob tidak keluar melewati radius alas joystick (joystickRadius).
    func updateJoystickKnob(touchLocation: CGPoint) {
        let dx = touchLocation.x - joystickBase.position.x
        let dy = touchLocation.y - joystickBase.position.y
        let distance = sqrt(dx*dx + dy*dy)
        let angle = atan2(dy, dx)
        
        if distance <= joystickRadius {
            // Jari masih di dalam batas radius -> posisikan knob tepat di bawah jari
            joystickKnob.position = CGPoint(x: dx, y: dy)
            joystickVector = CGPoint(x: dx / joystickRadius, y: dy / joystickRadius)
        } else {
            // Jari keluar batas -> posisikan knob secara presisi di batas lingkar luar radius
            let limitedX = cos(angle) * joystickRadius
            let limitedY = sin(angle) * joystickRadius
            joystickKnob.position = CGPoint(x: limitedX, y: limitedY)
            joystickVector = CGPoint(x: cos(angle), y: sin(angle))
        }
    }
    
    /// Mereset status joystick kembali netral (tidak aktif, knob kembali ke tengah/nol).
    func resetJoystick() {
        isJoystickActive = false
        joystickActiveTouch = nil
        joystickVector = CGPoint.zero
        
        let moveBack = SKAction.move(to: CGPoint.zero, duration: 0.1)
        joystickKnob.run(moveBack)
    }
    
    func setPencilTarget(_ requestedLocation: CGPoint) {
        let footprint = player?.collisionFootprint ?? gameMap.configuration.playerFootprint
        guard let acceptedLocation = walkabilitySystem.nearestWalkablePosition(
            to: requestedLocation,
            from: player?.position
                ?? geometryStore.configuration.spawnPoint(for: .sleepingRoom)
                ?? GameMapLayout.playerSpawnPosition,
            footprint: footprint
        ) else {
            pencilTarget = nil
            pencilBlockedFrameCount = 0
            showTargetMarker(at: requestedLocation, accepted: false, reason: .outsideShip)
            return
        }

        pencilTarget = acceptedLocation
        pencilBlockedFrameCount = 0
        showTargetMarker(at: acceptedLocation, accepted: true)
    }

    func clearPencilTarget() {
        pencilTarget = nil
        pencilBlockedFrameCount = 0
        hideTargetMarker()
    }

    func rejectCurrentPencilTarget(reason: BlockedAreaType) {
        let rejectedLocation = pencilTarget ?? player.position
        pencilTarget = nil
        pencilBlockedFrameCount = 0
        showTargetMarker(at: rejectedLocation, accepted: false, reason: reason)
    }

    /// Menampilkan penanda hijau untuk target valid atau merah untuk target yang ditolak.
    func showTargetMarker(
        at location: CGPoint,
        accepted: Bool = true,
        reason: BlockedAreaType? = nil
    ) {
        targetMarker?.removeFromParent()
        
        let marker = SKShapeNode(circleOfRadius: GameMapLayout.scaled(10))
        marker.fillColor = .clear
        marker.strokeColor = accepted
            ? SKColor.systemGreen.withAlphaComponent(0.9)
            : SKColor.systemRed.withAlphaComponent(0.95)
        marker.lineWidth = GameMapLayout.scaled(2)
        marker.position = location
        marker.zPosition = 5
        self.addChild(marker)
        targetMarker = marker

        if debugSettings.isMapDebugEnabled, let reason {
            let label = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
            label.text = reason.rawValue
            label.fontSize = GameMapLayout.scaled(9)
            label.fontColor = .systemRed
            label.position = CGPoint(x: 0, y: GameMapLayout.scaled(15))
            label.isUserInteractionEnabled = false
            marker.addChild(label)
        }
        
        // Animasi denyut (pulse) tiada henti
        let pulseOut = SKAction.scale(to: 1.5, duration: 0.4)
        let pulseIn = SKAction.scale(to: 1.0, duration: 0.4)
        let pulse = SKAction.repeatForever(SKAction.sequence([pulseOut, pulseIn]))
        marker.run(pulse)

        if !accepted {
            marker.run(.sequence([
                .wait(forDuration: 0.8),
                .fadeOut(withDuration: 0.2),
                .run { [weak self, weak marker] in
                    if self?.targetMarker === marker {
                        self?.targetMarker = nil
                    }
                    marker?.removeFromParent()
                }
            ]), withKey: "removeRejectedTarget")
        }
    }
    
    /// Menghapus penanda lingkaran biru navigasi target Apple Pencil.
    func hideTargetMarker() {
        targetMarker?.removeFromParent()
        targetMarker = nil
    }
}
