//
//  GameScene.swift
//  GameClassification
//
//  Created by Muhammad Muthi' Nuritzan on 09/07/26.
//

import SpriteKit

class GameScene: SKScene {
    
    // MARK: - Properties
    
    // Karakter game (berbentuk lingkaran biasa)
    private var player: SKShapeNode!
    
    // Node untuk Joystick (lingkaran luar & tombol kontrol di dalam)
    private var joystickBase: SKShapeNode!
    private var joystickKnob: SKShapeNode!
    
    // Container untuk grid ubin lantai agar mudah dihapus/dibuat ulang saat ukuran layar berubah
    private var gridContainer: SKNode?
    
    // Objek interaktif (easel papan gambar)
    private var interactiveObject: SKShapeNode!
    // Tombol "DRAW" di pojok kanan bawah
    private var actionButton: SKShapeNode?
    // Status tantangan
    private let totalChallenges = 5
    private var challengesCompleted = 0
    // Antrean tantangan acak (shuffled) — tiap objek muncul sekali dalam 5 ronde.
    private var challengeQueue: [DrawingChallenge] = []
    // Label progres ronde di bagian atas layar
    private var progressLabel: SKLabelNode?
    
    // Status joystick & arah pergerakan
    private var isJoystickActive = false
    private var joystickVector = CGPoint.zero // Vektor arah pergerakan (-1.0 sampai 1.0)
    private var joystickActiveTouch: UITouch? // Menyimpan touch aktif yang mengontrol joystick
    
    // Batas radius pergeseran tombol joystick (knob)
    private let joystickRadius: CGFloat = 60
    
    // Kecepatan gerak karakter
    private let playerSpeed: CGFloat = 4.0
    
    // MARK: - Apple Pencil Pointer Navigation (tap-to-move)
    // Apple Pencil berperan sebagai pointer: tap/drag Pencil menentukan titik
    // tujuan karakter. Berbeda dari joystick jari (analog), ini metafora pointer.
    private var pencilTouch: UITouch?       // Touch Pencil yang sedang aktif (untuk pressure)
    private var pencilTarget: CGPoint?      // Titik tujuan karakter (dipertahankan setelah Pencil angkat)
    private var pencilSpeedMultiplier: CGFloat = 1.0 // Modulasi kecepatan dari tekanan Pencil
    private var targetMarker: SKShapeNode?  // Marker visual lingkaran di titik tujuan
    // Threshold jarak: karakter dianggap sampai & berhenti saat jarak ke target < ini.
    private let arrivalThreshold: CGFloat = 4.0

    // MARK: - Scene Lifecycle
    
    override func didMove(to view: SKView) {
        // 1. Mengatur warna background area game
        self.backgroundColor = SKColor(red: 0.12, green: 0.14, blue: 0.2, alpha: 1.0)
        
        // 2. Menggambar Lantai Grid Kotak Biasa (Penuhi Layar)
        createRegularGrid()
        
        // 3. Membuat Karakter Player (Lingkaran)
        createPlayer()
        
        // 4. Membuat Analog Joystick
        createJoystick()
        
        // 5. Membuat Objek Interaktif (Easel)
        createInteractiveObject()
        
        // 6. Siapkan antrean tantangan acak & label progres
        challengeQueue = DrawingChallenge.all.shuffled()
        createProgressLabel()
    }
    
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        
        // 1. Gambar ulang grid lantai agar sesuai dengan ukuran layar yang baru
        createRegularGrid()
        
        // 2. Batasi karakter agar tetap berada di dalam layar baru (tidak terlempar keluar layar)
        if let player = player {
            let playerRadius: CGFloat = 15
            let newX = max(playerRadius, min(self.size.width - playerRadius, player.position.x))
            let newY = max(playerRadius, min(self.size.height - playerRadius, player.position.y))
            player.position = CGPoint(x: newX, y: newY)
        }
        
        // 3. Pastikan joystick tetap berada di pojok kiri bawah layar yang baru
        if let joystickBase = joystickBase {
            joystickBase.position = CGPoint(x: joystickRadius + 50, y: joystickRadius + 70)
        }
        
        // 4. Reposisi objek interaktif (easel)
        if let interactiveObject = interactiveObject {
            interactiveObject.position = CGPoint(x: self.size.width / 2, y: self.size.height * 0.8)
        }
        
        // 5. Reposisi tombol aksi jika sedang aktif
        if let actionButton = actionButton {
            let btnRadius: CGFloat = 40
            actionButton.position = CGPoint(x: self.size.width - btnRadius - 50, y: joystickRadius + 70)
        }
        
        // 6. Reposisi label progres ronde
        if let progressLabel = progressLabel {
            progressLabel.position = CGPoint(x: self.size.width / 2, y: self.size.height - 40)
        }
    }
    
    // MARK: - Setup UI & Nodes
    
    private func createRegularGrid() {
        // Hapus container grid lama jika ada agar tidak menumpuk
        gridContainer?.removeFromParent()
        
        let container = SKNode()
        gridContainer = container
        self.addChild(container)
        
        let tileSize: CGFloat = 60
        
        // Menghitung jumlah kolom & baris dinamis agar grid kotak memenuhi seluruh layar
        let cols = Int(ceil(self.size.width / tileSize))
        let rows = Int(ceil(self.size.height / tileSize))
        
        for row in 0..<rows {
            for col in 0..<cols {
                // Menghitung posisi tengah dari setiap tile kotak
                let xPos = CGFloat(col) * tileSize + tileSize / 2
                let yPos = CGFloat(row) * tileSize + tileSize / 2
                
                // Membuat ubin berbentuk kotak biasa
                let tile = SKShapeNode(rectOf: CGSize(width: tileSize, height: tileSize))
                tile.position = CGPoint(x: xPos, y: yPos)
                
                // Pola warna berselang-seling (papan catur)
                tile.fillColor = (row + col) % 2 == 0 ?
                    SKColor(red: 0.18, green: 0.22, blue: 0.3, alpha: 1.0) :
                    SKColor(red: 0.15, green: 0.18, blue: 0.25, alpha: 1.0)
                tile.strokeColor = SKColor(red: 0.25, green: 0.3, blue: 0.4, alpha: 1.0)
                tile.lineWidth = 1.0
                tile.zPosition = -1 // Agar selalu berada di belakang karakter utama
                
                container.addChild(tile)
            }
        }
    }
    
    private func createPlayer() {
        // Membuat karakter dengan bentuk lingkaran biasa berdiameter 30 (radius 15)
        player = SKShapeNode(circleOfRadius: 15)
        player.fillColor = SKColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0) // Merah menyala
        player.strokeColor = .white
        player.lineWidth = 2.0
        
        // Posisikan karakter di tengah layar awal
        player.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2)
        player.zPosition = 1
        
        self.addChild(player)
    }
    
    private func createJoystick() {
        // 1. Lingkaran Luar (Base)
        joystickBase = SKShapeNode(circleOfRadius: joystickRadius)
        // Posisi di pojok kiri bawah layar
        joystickBase.position = CGPoint(x: joystickRadius + 50, y: joystickRadius + 70)
        joystickBase.fillColor = SKColor.black.withAlphaComponent(0.2)
        joystickBase.strokeColor = SKColor.white.withAlphaComponent(0.6)
        joystickBase.lineWidth = 3
        joystickBase.zPosition = 10
        self.addChild(joystickBase)
        
        // 2. Lingkaran Dalam (Knob)
        joystickKnob = SKShapeNode(circleOfRadius: 25)
        joystickKnob.position = CGPoint.zero
        joystickKnob.fillColor = SKColor.white.withAlphaComponent(0.8)
        joystickKnob.strokeColor = .clear
        joystickKnob.zPosition = 11
        joystickBase.addChild(joystickKnob)
    }
    
    private func createInteractiveObject() {
        // Membuat board easel
        interactiveObject = SKShapeNode(rectOf: CGSize(width: 50, height: 40), cornerRadius: 8)
        interactiveObject.fillColor = SKColor(red: 0.82, green: 0.55, blue: 0.28, alpha: 1.0) // Wood color
        interactiveObject.strokeColor = .white
        interactiveObject.lineWidth = 2.0
        interactiveObject.position = CGPoint(x: self.size.width / 2, y: self.size.height * 0.8)
        interactiveObject.zPosition = 2
        self.addChild(interactiveObject)
        
        // Menambahkan kanvas kecil di dalam board
        let canvasInner = SKShapeNode(rectOf: CGSize(width: 36, height: 28), cornerRadius: 4)
        canvasInner.fillColor = .white
        canvasInner.strokeColor = .clear
        canvasInner.position = CGPoint.zero
        canvasInner.zPosition = 3
        interactiveObject.addChild(canvasInner)
        
        // Menambahkan gambar coretan pensil simbolik di kanvas kecil
        let line = SKShapeNode(rectOf: CGSize(width: 22, height: 4), cornerRadius: 1)
        line.fillColor = .black
        line.strokeColor = .clear
        line.zRotation = CGFloat.pi / 4
        line.position = CGPoint.zero
        line.zPosition = 4
        canvasInner.addChild(line)
        
        // Membuat lingkaran cahaya berdenyut di sekitar easel
        let glow = SKShapeNode(circleOfRadius: 45)
        glow.strokeColor = SKColor(red: 0.15, green: 0.68, blue: 0.38, alpha: 0.4) // Green glow
        glow.lineWidth = 2.0
        glow.zPosition = 1
        
        let scaleUp = SKAction.scale(to: 1.25, duration: 1.2)
        let scaleDown = SKAction.scale(to: 0.85, duration: 1.2)
        let pulse = SKAction.repeatForever(SKAction.sequence([scaleUp, scaleDown]))
        glow.run(pulse)
        
        interactiveObject.addChild(glow)
    }
    
    // MARK: - Proximity Detection & Action Button
    
    private func checkProximityToInteractiveObject() {
        guard let player = player, let interactiveObject = interactiveObject, challengesCompleted < totalChallenges else {
            hideInteractionButton()
            return
        }
        
        let dx = player.position.x - interactiveObject.position.x
        let dy = player.position.y - interactiveObject.position.y
        let distance = sqrt(dx*dx + dy*dy)
        
        let interactionRadius: CGFloat = 80.0
        if distance <= interactionRadius {
            showInteractionButton()
        } else {
            hideInteractionButton()
        }
    }
    
    private func showInteractionButton() {
        guard actionButton == nil else { return }
        
        let btnRadius: CGFloat = 40
        let button = SKShapeNode(circleOfRadius: btnRadius)
        button.position = CGPoint(x: self.size.width - btnRadius - 50, y: joystickRadius + 70)
        button.fillColor = SKColor(red: 0.9, green: 0.5, blue: 0.15, alpha: 1.0) // Orange button
        button.strokeColor = .white
        button.lineWidth = 3
        button.zPosition = 10
        button.name = "drawButton"
        
        let scaleUp = SKAction.scale(to: 1.08, duration: 0.7)
        let scaleDown = SKAction.scale(to: 0.92, duration: 0.7)
        let pulse = SKAction.repeatForever(SKAction.sequence([scaleUp, scaleDown]))
        button.run(pulse)
        
        let label = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        label.text = "DRAW"
        label.fontSize = 16
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: -5)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.name = "drawButton"
        
        button.addChild(label)
        self.addChild(button)
        actionButton = button
    }
    
    private func hideInteractionButton() {
        guard let button = actionButton else { return }
        button.removeFromParent()
        actionButton = nil
    }
    
    // MARK: - Drawing Challenge Presentation
    
    private func createProgressLabel() {
        progressLabel?.removeFromParent()
        let label = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        label.fontSize = 18
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.zPosition = 15
        label.position = CGPoint(x: self.size.width / 2, y: self.size.height - 40)
        updateProgressLabel(label)
        self.addChild(label)
        progressLabel = label
    }
    
    private func updateProgressLabel(_ label: SKLabelNode) {
        label.text = "TANTANGAN: \(challengesCompleted)/\(totalChallenges)"
    }
    
    private func presentDrawingCanvas() {
        // Jika semua tantangan sudah selesai, jangan present lagi.
        guard challengesCompleted < totalChallenges else { return }
        
        self.isPaused = true
        resetJoystick()
        // Hentikan navigasi Pencil saat kanvas gambar muncul agar karakter tidak
        // bergerak ke target lama saat scene di-resume.
        pencilTouch = nil
        pencilTarget = nil
        pencilSpeedMultiplier = 1.0
        hideTargetMarker()
        
        guard let viewController = self.view?.window?.rootViewController else { return }
        
        let drawingVC = DrawingViewController()
        // Ambil tantangan berikutnya dari antrean acak.
        drawingVC.challenge = challengeQueue[challengesCompleted]
        drawingVC.challengeIndex = challengesCompleted + 1
        drawingVC.totalChallenges = totalChallenges
        
        drawingVC.onSuccess = { [weak self] in
            self?.isPaused = false
            self?.handleDrawingSuccess()
        }
        
        drawingVC.onCancel = { [weak self] in
            self?.isPaused = false
        }
        
        drawingVC.modalPresentationStyle = .overFullScreen
        drawingVC.modalTransitionStyle = .crossDissolve
        viewController.present(drawingVC, animated: true, completion: nil)
    }
    
    private func handleDrawingSuccess() {
        challengesCompleted += 1
        
        // Update label progres ronde
        if let progressLabel = progressLabel {
            updateProgressLabel(progressLabel)
        }
        
        // Sembunyikan tombol draw sementara (akan muncul lagi saat player mendekat,
        // selama belum semua tantangan selesai).
        hideInteractionButton()
        
        if challengesCompleted >= totalChallenges {
            // Semua tantangan selesai: ubah easel jadi hijau & tampilkan banner final.
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
            // Ronde perantara: tampilkan banner sementara, easel tetap interaktif.
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
    
    // MARK: - Apple Pencil Detection
    
    // UITouch.type: .stylus = Apple Pencil 1, .pencil = Apple Pencil 2/USB-C/Pro.
    // .finger = sentuhan biasa. Memisahkan Pencil dari jari memungkinkan dua
    // gaya input berbeda (joystick jari vs pointer Pencil) tanpa saling ganggu.
    private func isPencilTouch(_ touch: UITouch) -> Bool {
        return touch.type == .stylus || touch.type == .pencil
    }
    
    // MARK: - Target Marker Helpers
    
    // Tampilkan/move marker lingkaran kecil di titik tujuan agar user melihat target.
    private func showTargetMarker(at point: CGPoint) {
        if targetMarker == nil {
            let marker = SKShapeNode(circleOfRadius: 10)
            marker.fillColor = SKColor(red: 0.15, green: 0.68, blue: 0.38, alpha: 0.4)
            marker.strokeColor = SKColor(red: 0.15, green: 0.68, blue: 0.38, alpha: 1.0)
            marker.lineWidth = 2.0
            marker.zPosition = 12
            self.addChild(marker)
            targetMarker = marker
        }
        targetMarker?.position = point
        
        // Efek denyut singkat agar terlihat jelas saat target berubah.
        targetMarker?.removeAction(forKey: "pulse")
        let pop = SKAction.sequence([SKAction.scale(to: 1.4, duration: 0.12), SKAction.scale(to: 1.0, duration: 0.12)])
        targetMarker?.run(pop, withKey: "pulse")
    }
    
    private func hideTargetMarker() {
        targetMarker?.removeFromParent()
        targetMarker = nil
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let touchLocation = touch.location(in: self)
            let nodesAtPoint = self.nodes(at: touchLocation)
            
            // 1. Tombol DRAW dideteksi untuk SEMUA tipe sentuhan (jari maupun
            //    Pencil), agar Pencil juga bisa tap tombol untuk membuka kanvas.
            for node in nodesAtPoint {
                if node.name == "drawButton" {
                    presentDrawingCanvas()
                    return
                }
            }
            
            // 2. Apple Pencil → navigasi pointer (tap-to-move).
            //    Pencil tidak memicu joystick; dua input eksklusif.
            if isPencilTouch(touch) {
                // Pencil down: simpan touch (untuk pressure), set titik tujuan,
                // dan tampilkan marker. Saat drag, target akan di-update di touchesMoved.
                pencilTouch = touch
                pencilTarget = touchLocation
                updatePencilSpeedMultiplier(from: touch)
                showTargetMarker(at: touchLocation)
                continue
            }
            
            // 3. Finger → joystick (logik lama, tidak berubah).
            if joystickBase.contains(touchLocation) {
                isJoystickActive = true
                joystickActiveTouch = touch
                updateJoystickKnob(touchLocation: touchLocation)
                break
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Apple Pencil drag → pindahkan titik tujuan + update kecepatan dari tekanan.
        if let activePencil = pencilTouch, touches.contains(activePencil) {
            let loc = activePencil.location(in: self)
            pencilTarget = loc
            updatePencilSpeedMultiplier(from: activePencil)
            showTargetMarker(at: loc)
            return
        }
        
        // Finger → joystick (logik lama).
        guard isJoystickActive, let activeTouch = joystickActiveTouch else { return }
        
        if touches.contains(activeTouch) {
            let touchLocation = activeTouch.location(in: self)
            updateJoystickKnob(touchLocation: touchLocation)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Apple Pencil angkat: bersihkan touch & reset multiplier, TAPI pertahankan
        // pencilTarget agar karakter terus jalan ke titik terakhir dan berhenti saat sampai.
        if let activePencil = pencilTouch, touches.contains(activePencil) {
            pencilTouch = nil
            pencilSpeedMultiplier = 1.0
            return
        }
        
        // Finger → joystick reset.
        guard let activeTouch = joystickActiveTouch else { return }
        
        if touches.contains(activeTouch) {
            resetJoystick()
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Pencil dibatalkan: hentikan sepenuhnya (clear touch + target + marker).
        if pencilTouch != nil {
            pencilTouch = nil
            pencilTarget = nil
            pencilSpeedMultiplier = 1.0
            hideTargetMarker()
        }
        resetJoystick()
    }
    
    // Konversi tekanan Pencil menjadi multiplier kecepatan 0.5x–1.5x.
    // Tekan ringan = 0.5x, tekan penuh = 1.5x. Perangkat tanpa force sensor
    // (maximumPossibleForce == 0, mis. simulator) memakai 1.0x.
    private func updatePencilSpeedMultiplier(from touch: UITouch) {
        let maxForce = touch.maximumPossibleForce
        guard maxForce > 0 else { pencilSpeedMultiplier = 1.0; return }
        let ratio = min(max(touch.force / maxForce, 0.0), 1.0) // 0.0 ... 1.0
        pencilSpeedMultiplier = 0.5 + ratio * 1.0 // 0.5x ... 1.5x
    }
    
    // MARK: - Joystick Physics / Logic
    
    private func updateJoystickKnob(touchLocation: CGPoint) {
        let dx = touchLocation.x - joystickBase.position.x
        let dy = touchLocation.y - joystickBase.position.y
        let distance = sqrt(dx*dx + dy*dy)
        let angle = atan2(dy, dx)
        
        if distance <= joystickRadius {
            joystickKnob.position = CGPoint(x: dx, y: dy)
            joystickVector = CGPoint(x: dx / joystickRadius, y: dy / joystickRadius)
        } else {
            let limitedX = cos(angle) * joystickRadius
            let limitedY = sin(angle) * joystickRadius
            joystickKnob.position = CGPoint(x: limitedX, y: limitedY)
            joystickVector = CGPoint(x: cos(angle), y: sin(angle))
        }
    }
    
    private func resetJoystick() {
        isJoystickActive = false
        joystickActiveTouch = nil
        joystickVector = CGPoint.zero
        
        let moveBack = SKAction.move(to: CGPoint.zero, duration: 0.1)
        joystickKnob.run(moveBack)
    }
    
    // MARK: - Game Loop Update
    
    override func update(_ currentTime: TimeInterval) {
        // Prioritas: navigasi Pencil (pointer) > joystick jari.
        // Pencil aktif selama pencilTarget != nil (bahkan setelah Pencil diangkat,
        // karakter terus menuju target dan berhenti saat sampai).
        if pencilTarget != nil {
            movePlayerTowardTarget()
        } else if isJoystickActive && joystickVector != CGPoint.zero {
            movePlayer()
        }
        
        checkProximityToInteractiveObject()
    }
    
    private func movePlayer() {
        let jx = joystickVector.x
        let jy = joystickVector.y
        
        // --- PERGERAKAN LURUS SCREEN-SPACE (2D) ---
        let dx = jx * playerSpeed
        let dy = jy * playerSpeed
        
        var newPosition = CGPoint(x: player.position.x + dx, y: player.position.y + dy)
        
        // Batasi karakter agar tidak keluar dari area layar game (Screen Boundaries Check)
        let playerRadius: CGFloat = 15
        
        newPosition.x = max(playerRadius, min(self.size.width - playerRadius, newPosition.x))
        newPosition.y = max(playerRadius, min(self.size.height - playerRadius, newPosition.y))
        
        player.position = newPosition
    }
    
    // Navigasi pointer Apple Pencil: karakter jalan menuju pencilTarget.
    // Berhenti otomatis saat jarak < arrivalThreshold; target & marker dibersihkan.
    private func movePlayerTowardTarget() {
        guard let target = pencilTarget else { return }
        
        let dx = target.x - player.position.x
        let dy = target.y - player.position.y
        let distance = sqrt(dx*dx + dy*dy)
        
        // Karakter dianggap sampai → hentikan & hapus target.
        if distance <= arrivalThreshold {
            pencilTarget = nil
            hideTargetMarker()
            return
        }
        
        // Normalisasi arah & kalikan dengan kecepatan (× multiplier tekanan Pencil).
        let step = playerSpeed * pencilSpeedMultiplier
        let nx = dx / distance
        let ny = dy / distance
        
        // Cegah overshoot: jika langkah lebih besar dari sisa jarak, langsung sampai.
        let moveStep = min(step, distance)
        var newPosition = CGPoint(x: player.position.x + nx * moveStep,
                                  y: player.position.y + ny * moveStep)
        
        // Batasi karakter agar tidak keluar dari area layar (Screen Boundaries Check).
        let playerRadius: CGFloat = 15
        newPosition.x = max(playerRadius, min(self.size.width - playerRadius, newPosition.x))
        newPosition.y = max(playerRadius, min(self.size.height - playerRadius, newPosition.y))
        
        player.position = newPosition
    }
}
