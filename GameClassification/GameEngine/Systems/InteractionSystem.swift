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
    
    /// Memeriksa jarak player ke seluruh papan lukis tantangan (Easel Tantangan).
    /// Jika player berada dalam jarak <= 80 poin dari salah satunya, munculkan tombol "DRAW" untuk menggambar.
    func checkProximityToInteractiveObject() {
        guard let player = player else {
            activeEasel = nil
            hideInteractionButton()
            return
        }
        
        var nearEasel: SKShapeNode? = nil
        for easel in challengeEasels {
            let dx = player.position.x - easel.position.x
            let dy = player.position.y - easel.position.y
            let distance = sqrt(dx*dx + dy*dy)
            if distance <= 80 {
                nearEasel = easel
                break
            }
        }
        
        if let easel = nearEasel {
            let isLab = easel.position.y > 1300
            
            if isLab {
                // Lab easel: cek apakah easel ini sudah selesai (per-easel tracking).
                let isCompleted = completedLabEasels.contains(easel.name ?? "")
                if !isCompleted {
                    activeEasel = easel
                    showInteractionButton()
                } else {
                    activeEasel = nil
                    hideInteractionButton()
                }
            } else {
                // Engine easel: terkunci sampai AI Intelligence >= 40%.
                let isCompleted = engineChallengesCompleted >= 5
                if isCompleted {
                    activeEasel = nil
                    hideInteractionButton()
                } else if aiIntelligence < aiIntelligenceEngineUnlockThreshold {
                    // Engine belum dibuka — tampilkan pesan terkunci.
                    activeEasel = nil
                    hideInteractionButton()
                    showEngineLockedMessage()
                } else {
                    activeEasel = easel
                    showInteractionButton()
                }
            }
        } else {
            activeEasel = nil
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
    
    /// Menampilkan tombol "DRAW" (berwarna jingga) pada kamera untuk memulai tantangan gambar utama.
    /// Mematikan tombol "EAT" agar tombol aksi tidak saling bertabrakan/bertumpuk di layar.
    func showInteractionButton() {
        hideFoodInteractionButton()
        
        if actionButton != nil { return } // Tombol sudah aktif
        
        let btnRadius: CGFloat = 40
        let button = SKShapeNode(circleOfRadius: btnRadius)
        button.fillColor = SKColor(red: 0.9, green: 0.5, blue: 0.15, alpha: 1.0)
        button.strokeColor = .white
        button.lineWidth = 2.0
        
        let w = self.size.width
        let h = self.size.height
        button.position = CGPoint(x: w / 2 - btnRadius - 50, y: -h / 2 + joystickRadius + 70)
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
        
        cameraNode.addChild(button)
        actionButton = button
    }
    
    /// Menyembunyikan tombol "DRAW".
    func hideInteractionButton() {
        guard let button = actionButton else { return }
        button.removeFromParent()
        actionButton = nil
    }
    
    /// Menampilkan pesan "Engine terkunci" singkat di tengah layar saat player mendekati engine
    /// tetapi AI Intelligence belum mencapai 40%.
    func showEngineLockedMessage() {
        // Hanya tampilkan satu pesan pada satu waktu.
        if childNode(withName: "//engineLockedMsg") != nil { return }
        
        let msg = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        msg.text = "ENGINE TERKUNCI! Selesaikan Lab dulu (AI Intel ≥ 40%)"
        msg.fontSize = 16
        msg.fontColor = SKColor(red: 0.74, green: 0.25, blue: 0.25, alpha: 1.0)
        msg.position = CGPoint.zero
        msg.zPosition = 20
        msg.name = "engineLockedMsg"
        cameraNode.addChild(msg)
        
        let fadeOut = SKAction.fadeOut(withDuration: 2.5)
        let remove = SKAction.removeFromParent()
        msg.run(SKAction.sequence([fadeOut, remove]))
    }
    
    /// Menampilkan tombol "EAT" (berwarna hijau) pada kamera untuk memulai tantangan menggambar makanan.
    /// Mematikan tombol "DRAW" agar tombol aksi tidak bertumpuk di layar.
    func showFoodInteractionButton() {
        hideInteractionButton()
        
        if foodActionButton != nil { return } // Tombol makan sudah aktif
        
        let btnRadius: CGFloat = 40
        let button = SKShapeNode(circleOfRadius: btnRadius)
        button.fillColor = SKColor(red: 0.15, green: 0.68, blue: 0.38, alpha: 1.0) // Hijau segar
        button.strokeColor = .white
        button.lineWidth = 2.0
        
        let w = self.size.width
        let h = self.size.height
        button.position = CGPoint(x: w / 2 - btnRadius - 50, y: -h / 2 + joystickRadius + 70)
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
        
        cameraNode.addChild(button)
        foodActionButton = button
    }
    
    /// Menyembunyikan tombol "EAT".
    func hideFoodInteractionButton() {
        guard let button = foodActionButton else { return }
        button.removeFromParent()
        foodActionButton = nil
    }
    
    /// Membuka pop-up canvas menggambar secara modal.
    /// - Parameter isFood: true jika menggambar makanan (stasiun makanan), false jika menggambar tantangan utama
    func presentDrawingCanvas(isFood: Bool) {
        // PERUBAHAN: Game tidak di-pause agar energy (stamina) tetap berkurang saat menggambar.
        resetJoystick()
        pencilTouch = nil
        pencilTarget = nil
        pencilSpeedMultiplier = 1.0
        hideTargetMarker()
        
        guard let viewController = self.view?.window?.rootViewController else { return }
        
        let drawingVC = DrawingChallengeViewController()
        
        if isFood {
            // Mode Makan: Pilih makanan acak dari daftar yang didukung oleh model CoreML
            guard let foodChallenge = DrawingChallenge.foodPool.randomElement() else { return }
            drawingVC.challenge = foodChallenge
            drawingVC.challengeIndex = 1
            drawingVC.totalChallenges = 1 // Hanya 1 ronde untuk pengisian makanan
            
            drawingVC.onSuccess = { [weak self] in
                guard let self = self, !self.isGameOver else { return }
                self.handleFoodDrawingSuccess()
            }
        } else {
            // Mode Utama: Selesaikan tantangan berdasarkan ruangan
            let isLab = (activeEasel?.position.y ?? 0) > 1300
            
            if isLab {
                // Lab: tiap easel punya challenge tetap (butterfly, spider, snake).
                guard let easelName = activeEasel?.name,
                      let challenge = labEaselChallengesMap[easelName],
                      !completedLabEasels.contains(easelName) else { return }
                
                drawingVC.challenge = challenge
                drawingVC.challengeIndex = labChallengesCompleted + 1
                drawingVC.totalChallenges = 3
                
                drawingVC.onSuccess = { [weak self] in
                    guard let self = self, !self.isGameOver else { return }
                    self.handleDrawingSuccess(room: "lab", easelName: easelName)
                }
            } else {
                // Engine: terkunci sampai AI Intelligence >= 40%.
                guard aiIntelligence >= aiIntelligenceEngineUnlockThreshold else { return }
                guard engineChallengesCompleted < 5 else { return }
                drawingVC.challenge = engineChallengeQueue[engineChallengesCompleted]
                drawingVC.challengeIndex = engineChallengesCompleted + 1
                drawingVC.totalChallenges = 5
                
                drawingVC.onSuccess = { [weak self] in
                    guard let self = self, !self.isGameOver else { return }
                    self.handleDrawingSuccess(room: "engine", easelName: nil)
                }
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
    func handleDrawingSuccess(room: String, easelName: String?) {
        if room == "lab" {
            // Lab: tandai easel ini selesai + tambah AI Intelligence 10%.
            if let name = easelName {
                completedLabEasels.insert(name)
            }
            aiIntelligence = min(maxAiIntelligence, aiIntelligence + aiIntelligencePerLabEasel)
            updateAiIntelligenceBarFill()
            
            // Ubah warna easel yang baru saja selesai menjadi hijau.
            if let name = easelName, let easel = challengeEasels.first(where: { $0.name == name }) {
                easel.fillColor = SKColor(red: 0.15, green: 0.68, blue: 0.38, alpha: 1.0)
                // Update marker di tactical map: tandai easel ini selesai.
                tacticalMapViewModel.completeLabEaselMarker(at: easel.position)
            }
            
            if labChallengesCompleted >= 3 {
                // Semua easel Lab selesai -> unlock engine marker di peta + tampilkan banner.
                tacticalMapViewModel.unlockEngineMarker()
                let unlockLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
                unlockLabel.text = "LAB SELESAI! ENGINE TERBUKA!"
                unlockLabel.fontSize = 22
                unlockLabel.fontColor = SKColor(red: 0.2, green: 0.7, blue: 1.0, alpha: 1.0)
                unlockLabel.position = CGPoint.zero
                unlockLabel.zPosition = 20
                cameraNode.addChild(unlockLabel)
                
                let fadeOut = SKAction.fadeOut(withDuration: 3.0)
                let remove = SKAction.removeFromParent()
                unlockLabel.run(SKAction.sequence([fadeOut, remove]))
            }
        } else {
            engineChallengesCompleted += 1
            if engineChallengesCompleted >= 5 {
                // Papan gambar Engine jadi hijau permanen
                if let engineEasel = challengeEasels.first(where: { $0.name == "engineEasel" }) {
                    engineEasel.fillColor = SKColor(red: 0.15, green: 0.68, blue: 0.38, alpha: 1.0)
                }
            }
        }
        
        if let progressLabel = progressLabel {
            updateProgressLabel(progressLabel)
        }
        
        hideInteractionButton()
        
        if engineChallengesCompleted >= 5 && labChallengesCompleted >= 3 {
            tacticalMapViewModel.completeActiveMissions()
            // Semua tantangan selesai -> Ubah warna semua easel tantangan menjadi hijau permanen dan tampilkan banner final
            for easel in challengeEasels {
                easel.fillColor = SKColor(red: 0.15, green: 0.68, blue: 0.38, alpha: 1.0)
            }
            
            let successLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
            successLabel.text = "SEMUA TANTANGAN BERHASIL!"
            successLabel.fontSize = 24
            successLabel.fontColor = SKColor(red: 0.15, green: 0.68, blue: 0.38, alpha: 1.0)
            successLabel.position = CGPoint.zero
            successLabel.zPosition = 20
            cameraNode.addChild(successLabel)
            
            let fadeOut = SKAction.fadeOut(withDuration: 3.5)
            let remove = SKAction.removeFromParent()
            successLabel.run(SKAction.sequence([fadeOut, remove]))
        } else {
            // Sukses ronde perantara -> Tampilkan banner ronde transisi
            let roundLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
            let roomName = room == "lab" ? "LAB" : "ENGINE"
            let comp = room == "lab" ? labChallengesCompleted : engineChallengesCompleted
            let total = room == "lab" ? 3 : 5
            roundLabel.text = "RONDE \(roomName) \(comp)/\(total) SELESAI!"
            roundLabel.fontSize = 22
            roundLabel.fontColor = SKColor(red: 0.15, green: 0.68, blue: 0.38, alpha: 1.0)
            roundLabel.position = CGPoint.zero
            roundLabel.zPosition = 20
            cameraNode.addChild(roundLabel)
            
            let fadeOut = SKAction.fadeOut(withDuration: 2.5)
            let remove = SKAction.removeFromParent()
            roundLabel.run(SKAction.sequence([fadeOut, remove]))
        }
    }
    
    /// Dipanggil saat user sukses menggambar makanan -> Mengisi stamina bertambah 50%.
    func handleFoodDrawingSuccess() {
        // PERUBAHAN: Energi yang bertambah hanya 50% dari maxStamina (dibatasi hingga maksimum maxStamina).
        stamina = min(maxStamina, stamina + 0.50 * maxStamina)
        updateStaminaBarFill()
        
        let successLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        successLabel.text = "ENERGI BERTAMBAH 50%!"
        successLabel.fontSize = 24
        successLabel.fontColor = SKColor(red: 0.9, green: 0.5, blue: 0.15, alpha: 1.0)
        successLabel.position = CGPoint.zero
        successLabel.zPosition = 20
        cameraNode.addChild(successLabel)
        
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
        tacticalMapViewModel.closeMap()
        sessionState.endGameplay()
        resetJoystick()
        pencilTouch = nil
        pencilTarget = nil
        hideTargetMarker()
        
        // PERUBAHAN: Tutup paksa popup menggambar jika sedang aktif saat Game Over terjadi.
        if let rootVC = self.view?.window?.rootViewController {
            if rootVC.presentedViewController is DrawingChallengeViewController {
                rootVC.dismiss(animated: true, completion: nil)
            }
        }
        
        gameOverNode?.removeFromParent()
        
        let container = SKNode()
        container.position = CGPoint.zero // camera center is (0, 0)
        container.zPosition = 30
        cameraNode.addChild(container)
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
        engineChallengesCompleted = 0
        completedLabEasels.removeAll()
        aiIntelligence = 10.0 // Reset AI Intelligence ke 10% (awal)
        engineChallengeQueue = DrawingChallenge.enginePool.shuffled()
        
        // Update tampilan UI
        if let progressLabel {
            updateProgressLabel(progressLabel)
        }
        updateStaminaBarFill()
        updateAiIntelligenceBarFill()
        
        // Reset player & warna easel tantangan
        player.position = GameMapLayout.playerSpawnPosition
        tacticalMapViewModel.resetMissionMarkers()
        sessionState.updateLocalPlayer(position: player.position)
        sessionState.beginGameplay()
        for easel in challengeEasels {
            easel.fillColor = SKColor(red: 0.82, green: 0.55, blue: 0.28, alpha: 1.0) // warna kayu
        }
        
        self.isPaused = false
    }
}
