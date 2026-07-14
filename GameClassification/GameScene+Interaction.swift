//
//  GameScene+Interaction.swift
//  GameClassification
//
//  Created by Muhammad Muthi' Nuritzan on 14/07/26.
//

import SpriteKit
import UIKit

// Extension ini khusus menangani sistem interaksi antarpemain dengan objek di map
// (easel gambar dan stasiun makanan), presentasi kanvas popup, serta status Game Over & Restart.
extension GameScene {
    
    /// Memeriksa jarak player ke papan lukis utama (Easel Tantangan).
    /// Jika player berada dalam jarak <= 80 poin, munculkan tombol "DRAW" untuk menggambar.
    func checkProximityToInteractiveObject() {
        guard let player = player, let interactiveObject = interactiveObject else { return }
        
        let dx = player.position.x - interactiveObject.position.x
        let dy = player.position.y - interactiveObject.position.y
        let distance = sqrt(dx*dx + dy*dy)
        
        if distance <= 80 && challengesCompleted < totalChallenges {
            showInteractionButton()
        } else {
            hideInteractionButton()
        }
    }
    
    /// Memeriksa jarak player ke stasiun makanan (Food Easel).
    /// Jika player berada dalam jarak <= 80 poin, munculkan tombol "EAT" untuk mengisi energi.
    func checkProximityToFoodObject() {
        guard let player = player, let foodObject = foodObject else { return }
        
        let dx = player.position.x - foodObject.position.x
        let dy = player.position.y - foodObject.position.y
        let distance = sqrt(dx*dx + dy*dy)
        
        if distance <= 80 {
            showFoodInteractionButton()
        } else {
            hideFoodInteractionButton()
        }
    }
    
    /// Menampilkan tombol "DRAW" (berwarna jingga) untuk memulai tantangan gambar utama.
    /// Mematikan tombol "EAT" agar tombol aksi tidak saling bertabrakan/bertumpuk di layar.
    func showInteractionButton() {
        hideFoodInteractionButton()
        
        if actionButton != nil { return } // Tombol sudah aktif
        
        let btnRadius: CGFloat = 40
        let button = SKShapeNode(circleOfRadius: btnRadius)
        button.fillColor = SKColor(red: 0.9, green: 0.5, blue: 0.15, alpha: 1.0)
        button.strokeColor = .white
        button.lineWidth = 2.0
        button.position = CGPoint(x: self.size.width - btnRadius - 50, y: joystickRadius + 70)
        button.zPosition = 12
        button.name = "drawButton"
        
        let label = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        label.text = "DRAW"
        label.fontSize = 14
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.name = "drawButton"
        button.addChild(label)
        
        // Animasi denyut halus agar menarik perhatian user
        let scaleUp = SKAction.scale(to: 1.15, duration: 0.6)
        let scaleDown = SKAction.scale(to: 0.95, duration: 0.6)
        let pulse = SKAction.repeatForever(SKAction.sequence([scaleUp, scaleDown]))
        button.run(pulse)
        
        self.addChild(button)
        actionButton = button
    }
    
    /// Menyembunyikan tombol "DRAW".
    func hideInteractionButton() {
        guard let button = actionButton else { return }
        button.removeFromParent()
        actionButton = nil
    }
    
    /// Menampilkan tombol "EAT" (berwarna hijau) untuk memulai tantangan menggambar makanan.
    /// Mematikan tombol "DRAW" agar tombol aksi tidak bertumpuk di layar.
    func showFoodInteractionButton() {
        hideInteractionButton()
        
        if foodActionButton != nil { return } // Tombol makan sudah aktif
        
        let btnRadius: CGFloat = 40
        let button = SKShapeNode(circleOfRadius: btnRadius)
        button.fillColor = SKColor(red: 0.15, green: 0.68, blue: 0.38, alpha: 1.0) // Hijau segar
        button.strokeColor = .white
        button.lineWidth = 2.0
        button.position = CGPoint(x: self.size.width - btnRadius - 50, y: joystickRadius + 70)
        button.zPosition = 12
        button.name = "foodDrawButton"
        
        let label = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        label.text = "EAT"
        label.fontSize = 14
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.name = "foodDrawButton"
        button.addChild(label)
        
        let scaleUp = SKAction.scale(to: 1.15, duration: 0.6)
        let scaleDown = SKAction.scale(to: 0.95, duration: 0.6)
        let pulse = SKAction.repeatForever(SKAction.sequence([scaleUp, scaleDown]))
        button.run(pulse)
        
        self.addChild(button)
        foodActionButton = button
    }
    
    /// Menyembunyikan tombol "EAT".
    func hideFoodInteractionButton() {
        guard let button = foodActionButton else { return }
        button.removeFromParent()
        foodActionButton = nil
    }
    
    /// Membuka (present) pop-up canvas menggambar `DrawingViewController` secara modal.
    /// - Parameter isFood: true jika menggambar makanan (stasiun makanan), false jika menggambar tantangan utama
    func presentDrawingCanvas(isFood: Bool) {
        self.isPaused = true // Jeda permainan agar stamina tidak berkurang saat menggambar
        resetJoystick()
        pencilTouch = nil
        pencilTarget = nil
        pencilSpeedMultiplier = 1.0
        hideTargetMarker()
        
        guard let viewController = self.view?.window?.rootViewController else { return }
        
        let drawingVC = DrawingViewController()
        
        if isFood {
            // Mode Makan: Pilih makanan acak dari daftar yang didukung oleh model CoreML
            let foods = [
                DrawingChallenge(label: "banana", displayName: "PISANG"),
                DrawingChallenge(label: "apple", displayName: "APEL"),
                DrawingChallenge(label: "donut", displayName: "DONAT"),
                DrawingChallenge(label: "pizza", displayName: "PIZZA")
            ]
            let foodChallenge = foods.randomElement()!
            drawingVC.challenge = foodChallenge
            drawingVC.challengeIndex = 1
            drawingVC.totalChallenges = 1 // Hanya 1 ronde untuk pengisian makanan
            
            drawingVC.onSuccess = { [weak self] in
                self?.isPaused = false
                self?.handleFoodDrawingSuccess()
            }
        } else {
            // Mode Utama: Selesaikan daftar tantangan utama berurutan
            guard challengesCompleted < totalChallenges else { return }
            drawingVC.challenge = challengeQueue[challengesCompleted]
            drawingVC.challengeIndex = challengesCompleted + 1
            drawingVC.totalChallenges = totalChallenges
            
            drawingVC.onSuccess = { [weak self] in
                self?.isPaused = false
                self?.handleDrawingSuccess()
            }
        }
        
        // Ketika membatalkan menggambar, cukup lanjutkan kembali game
        drawingVC.onCancel = { [weak self] in
            self?.isPaused = false
        }
        
        drawingVC.modalPresentationStyle = .overFullScreen
        drawingVC.modalTransitionStyle = .crossDissolve
        viewController.present(drawingVC, animated: true, completion: nil)
    }
    
    /// Dipanggil saat user sukses menyelesaikan salah satu tantangan menggambar utama.
    func handleDrawingSuccess() {
        challengesCompleted += 1
        
        if let progressLabel = progressLabel {
            updateProgressLabel(progressLabel)
        }
        
        hideInteractionButton()
        
        if challengesCompleted >= totalChallenges {
            // Semua tantangan selesai -> Ubah warna easel utama menjadi hijau permanen dan tampilkan banner final
            interactiveObject.fillColor = SKColor(red: 0.15, green: 0.68, blue: 0.38, alpha: 1.0)
            
            let successLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
            successLabel.text = "SEMUA TANTANGAN BERHASIL!"
            successLabel.fontSize = 24
            successLabel.fontColor = SKColor(red: 0.15, green: 0.68, blue: 0.38, alpha: 1.0)
            successLabel.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2)
            successLabel.zPosition = 20
            self.addChild(successLabel)
            
            let fadeOut = SKAction.fadeOut(withDuration: 3.5)
            let remove = SKAction.removeFromParent()
            successLabel.run(SKAction.sequence([fadeOut, remove]))
        } else {
            // Sukses ronde perantara -> Tampilkan banner ronde transisi
            let roundLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
            roundLabel.text = "RONDE \(challengesCompleted)/\(totalChallenges) SELESAI!"
            roundLabel.fontSize = 22
            roundLabel.fontColor = SKColor(red: 0.15, green: 0.68, blue: 0.38, alpha: 1.0)
            roundLabel.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2)
            roundLabel.zPosition = 20
            self.addChild(roundLabel)
            
            let fadeOut = SKAction.fadeOut(withDuration: 2.5)
            let remove = SKAction.removeFromParent()
            roundLabel.run(SKAction.sequence([fadeOut, remove]))
        }
    }
    
    /// Dipanggil saat user sukses menggambar makanan -> Mengisi stamina kembali ke 100%.
    func handleFoodDrawingSuccess() {
        stamina = maxStamina
        updateStaminaBarFill()
        
        let successLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        successLabel.text = "ENERGI PULIH 100%!"
        successLabel.fontSize = 24
        successLabel.fontColor = SKColor(red: 0.9, green: 0.5, blue: 0.15, alpha: 1.0)
        successLabel.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2)
        successLabel.zPosition = 20
        self.addChild(successLabel)
        
        let fadeOut = SKAction.fadeOut(withDuration: 2.5)
        let remove = SKAction.removeFromParent()
        successLabel.run(SKAction.sequence([fadeOut, remove]))
        
        hideFoodInteractionButton()
    }
    
    /// Memicu status Game Over saat stamina habis (0%).
    /// Menjeda game dan menampilkan overlay layar penuh dengan tombol Restart.
    func triggerGameOver() {
        isGameOver = true
        self.isPaused = true
        resetJoystick()
        pencilTouch = nil
        pencilTarget = nil
        hideTargetMarker()
        
        gameOverNode?.removeFromParent()
        
        let container = SKNode()
        container.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2)
        container.zPosition = 30
        self.addChild(container)
        gameOverNode = container
        
        // Background hitam transparan menutup area layar
        let bg = SKShapeNode(rect: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))
        bg.fillColor = SKColor.black.withAlphaComponent(0.8)
        bg.strokeColor = .clear
        bg.name = "bg"
        container.addChild(bg)
        
        // Judul GAME OVER
        let title = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        title.text = "GAME OVER"
        title.fontSize = 42
        title.fontColor = SKColor(red: 0.74, green: 0.25, blue: 0.25, alpha: 1.0)
        title.position = CGPoint(x: 0, y: 50)
        container.addChild(title)
        
        // Subtitle pesan
        let subtitle = SKLabelNode(fontNamed: "HelveticaNeue")
        subtitle.text = "Energi Anda telah habis!"
        subtitle.fontSize = 18
        subtitle.fontColor = .white
        subtitle.position = CGPoint(x: 0, y: 10)
        container.addChild(subtitle)
        
        // Tombol Restart
        let btnWidth: CGFloat = 160
        let btnHeight: CGFloat = 44
        let restartBtn = SKShapeNode(rectOf: CGSize(width: btnWidth, height: btnHeight), cornerRadius: 8)
        restartBtn.fillColor = SKColor(red: 0.15, green: 0.68, blue: 0.38, alpha: 1.0)
        restartBtn.strokeColor = .white
        restartBtn.lineWidth = 1.5
        restartBtn.position = CGPoint(x: 0, y: -50)
        restartBtn.name = "restartButton"
        container.addChild(restartBtn)
        
        let restartLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        restartLabel.text = "RESTART"
        restartLabel.fontSize = 16
        restartLabel.fontColor = .white
        restartLabel.verticalAlignmentMode = .center
        restartLabel.horizontalAlignmentMode = .center
        restartLabel.name = "restartButton"
        restartBtn.addChild(restartLabel)
    }
    
    /// Mereset permainan kembali ke kondisi awal (stamina penuh, ronde reset ke 0, player di tengah).
    func restartGame() {
        gameOverNode?.removeFromParent()
        gameOverNode = nil
        isGameOver = false
        
        // Setel ulang variabel internal
        stamina = maxStamina
        challengesCompleted = 0
        challengeQueue = DrawingChallenge.all.shuffled()
        
        // Update tampilan UI
        updateProgressLabel(progressLabel!)
        updateStaminaBarFill()
        
        // Reset player & warna easel tantangan
        player.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2)
        interactiveObject.fillColor = SKColor(red: 0.82, green: 0.55, blue: 0.28, alpha: 1.0) // warna kayu
        
        self.isPaused = false
    }
}
