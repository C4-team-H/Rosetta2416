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
        // Jika status Game Over, sentuhan hanya mendeteksi tombol restart
        guard !isGameOver else {
            for touch in touches {
                let touchLocation = touch.location(in: self)
                let nodesAtPoint = self.nodes(at: touchLocation)
                for node in nodesAtPoint {
                    if node.name == "restartButton" {
                        restartGame()
                        return
                    }
                }
            }
            return
        }
        
        for touch in touches {
            let touchLocation = touch.location(in: self)
            let nodesAtPoint = self.nodes(at: touchLocation)
            
            // 1. Deteksi klik pada tombol interaktif (DRAW untuk stasiun utama, EAT untuk stasiun makanan)
            for node in nodesAtPoint {
                if node.name == "drawButton" {
                    presentDrawingCanvas(isFood: false)
                    return
                } else if node.name == "foodDrawButton" {
                    presentDrawingCanvas(isFood: true)
                    return
                }
            }
            
            // 2. Deteksi input dari Apple Pencil (Pointer navigation)
            // Mendukung .pencil (Apple Pencil 2/Pro/USB-C) dan .stylus (Apple Pencil 1)
            if touch.type == .pencil || touch.type == .stylus {
                pencilTouch = touch
                pencilTarget = touchLocation
                updatePencilSpeedMultiplier(from: touch)
                showTargetMarker(at: touchLocation)
                continue
            }
            
            // 3. Deteksi input dari jari biasa untuk mengendalikan Joystick analog
            if joystickBase.contains(touchLocation) {
                isJoystickActive = true
                joystickActiveTouch = touch
                updateJoystickKnob(touchLocation: touchLocation)
                break
            }
        }
    }
    
    /// Dipanggil saat jari atau Apple Pencil bergeser di atas layar.
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isGameOver else { return }
        
        // Geser Apple Pencil -> Pindahkan titik koordinat target bergerak
        if let activePencil = pencilTouch, touches.contains(activePencil) {
            let loc = activePencil.location(in: self)
            pencilTarget = loc
            updatePencilSpeedMultiplier(from: activePencil)
            showTargetMarker(at: loc)
            return
        }
        
        // Geser jari pada Joystick -> Update arah joystickVector
        guard isJoystickActive, let activeTouch = joystickActiveTouch else { return }
        if touches.contains(activeTouch) {
            let touchLocation = activeTouch.location(in: self)
            updateJoystickKnob(touchLocation: touchLocation)
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
            pencilTarget = nil
            pencilSpeedMultiplier = 1.0
            hideTargetMarker()
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
    
    /// Menampilkan animasi penanda lingkaran biru di titik target Apple Pencil (tap-to-move).
    func showTargetMarker(at location: CGPoint) {
        targetMarker?.removeFromParent()
        
        let marker = SKShapeNode(circleOfRadius: 10)
        marker.fillColor = .clear
        marker.strokeColor = SKColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 0.8)
        marker.lineWidth = 2.0
        marker.position = location
        marker.zPosition = 5
        self.addChild(marker)
        targetMarker = marker
        
        // Animasi denyut (pulse) tiada henti
        let pulseOut = SKAction.scale(to: 1.5, duration: 0.4)
        let pulseIn = SKAction.scale(to: 1.0, duration: 0.4)
        let pulse = SKAction.repeatForever(SKAction.sequence([pulseOut, pulseIn]))
        marker.run(pulse)
    }
    
    /// Menghapus penanda lingkaran biru navigasi target Apple Pencil.
    func hideTargetMarker() {
        targetMarker?.removeFromParent()
        targetMarker = nil
    }
}
