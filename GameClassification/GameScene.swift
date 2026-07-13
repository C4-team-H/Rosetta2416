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
    private var isChallengeCompleted = false
    
    // Status joystick & arah pergerakan
    private var isJoystickActive = false
    private var joystickVector = CGPoint.zero // Vektor arah pergerakan (-1.0 sampai 1.0)
    private var joystickActiveTouch: UITouch? // Menyimpan touch aktif yang mengontrol joystick
    
    // Batas radius pergeseran tombol joystick (knob)
    private let joystickRadius: CGFloat = 60
    
    // Kecepatan gerak karakter
    private let playerSpeed: CGFloat = 4.0

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
        guard let player = player, let interactiveObject = interactiveObject, !isChallengeCompleted else {
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
    
    private func presentDrawingCanvas() {
        self.isPaused = true
        resetJoystick()
        
        guard let viewController = self.view?.window?.rootViewController else { return }
        
        let drawingVC = DrawingViewController()
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
        isChallengeCompleted = true
        
        // Ubah warna papan easel menjadi hijau sukses
        interactiveObject.fillColor = SKColor(red: 0.15, green: 0.68, blue: 0.38, alpha: 1.0)
        
        // Sembunyikan tombol draw
        hideInteractionButton()
        
        // Menampilkan label perayaan di layar
        let successLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        successLabel.text = "TANTANGAN BERHASIL!"
        successLabel.fontSize = 24
        successLabel.fontColor = SKColor(red: 0.15, green: 0.68, blue: 0.38, alpha: 1.0)
        successLabel.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2)
        successLabel.zPosition = 20
        self.addChild(successLabel)
        
        let fadeOut = SKAction.fadeOut(withDuration: 3.5)
        let remove = SKAction.removeFromParent()
        successLabel.run(SKAction.sequence([fadeOut, remove]))
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let touchLocation = touch.location(in: self)
            let nodesAtPoint = self.nodes(at: touchLocation)
            
            for node in nodesAtPoint {
                if node.name == "drawButton" {
                    presentDrawingCanvas()
                    return
                }
            }
            
            // Cek apakah sentuhan pertama berada di dalam area joystick
            if joystickBase.contains(touchLocation) {
                isJoystickActive = true
                joystickActiveTouch = touch
                updateJoystickKnob(touchLocation: touchLocation)
                break
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isJoystickActive, let activeTouch = joystickActiveTouch else { return }
        
        if touches.contains(activeTouch) {
            let touchLocation = activeTouch.location(in: self)
            updateJoystickKnob(touchLocation: touchLocation)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeTouch = joystickActiveTouch else { return }
        
        if touches.contains(activeTouch) {
            resetJoystick()
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        resetJoystick()
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
        if isJoystickActive && joystickVector != CGPoint.zero {
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
}
