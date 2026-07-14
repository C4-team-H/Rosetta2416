//
//  GameScene.swift
//  GameClassification
//
//  Created by Muhammad Muthi' Nuritzan on 09/07/26.
//

import SpriteKit

class GameScene: SKScene {
    
    // MARK: - Properties
    let cameraNode = SKCameraNode() // Kamera untuk mengikuti pergerakan player
    var challengeEasels: [SKShapeNode] = [] // Daftar papan gambar tantangan
    
    // Karakter game (berbentuk lingkaran biasa)
    var player: SKShapeNode!
    
    // Node untuk Joystick (lingkaran luar & tombol kontrol di dalam)
    var joystickBase: SKShapeNode!
    var joystickKnob: SKShapeNode!
    
    // Container untuk grid ubin lantai agar mudah dihapus/dibuat ulang saat ukuran layar berubah
    var gridContainer: SKNode?
    
    // Objek interaktif (easel papan gambar)
    var interactiveObject: SKShapeNode!
    // Tombol "DRAW" di pojok kanan bawah
    var actionButton: SKShapeNode?
    
    // Objek interaktif Makanan
    var foodObject: SKShapeNode!
    var foodActionButton: SKShapeNode?
    
    // Status tantangan
    let totalChallenges = 5
    var challengesCompleted = 0
    // Antrean tantangan acak (shuffled) — tiap objek muncul sekali dalam 5 ronde.
    var challengeQueue: [DrawingChallenge] = []
    // Label progres ronde di bagian atas layar
    var progressLabel: SKLabelNode?
    
    // Fitur Stamina Progress Bar
    var stamina: CGFloat = 100.0
    let maxStamina: CGFloat = 100.0
    let staminaDecayRate: CGFloat = 0.025 // berkurang perlahan setiap frame update
    var staminaBarContainer: SKNode?
    
    // Status joystick & arah pergerakan
    var isJoystickActive = false
    var joystickVector = CGPoint.zero // Vektor arah pergerakan (-1.0 sampai 1.0)
    var joystickActiveTouch: UITouch? // Menyimpan touch aktif yang mengontrol joystick
    
    // Batas radius pergeseran tombol joystick (knob)
    let joystickRadius: CGFloat = 60
    
    // Kecepatan gerak karakter
    let playerSpeed: CGFloat = 4.0
    
    // MARK: - Apple Pencil Pointer Navigation (tap-to-move)
    var pencilTouch: UITouch?       // Touch Pencil yang sedang aktif
    var pencilTarget: CGPoint?      // Titik tujuan karakter
    var pencilSpeedMultiplier: CGFloat = 1.0
    var targetMarker: SKShapeNode?  // Marker visual lingkaran di titik tujuan
    let arrivalThreshold: CGFloat = 4.0
    
    // MARK: - Obstacles
    struct Obstacle {
        let node: SKNode
        let size: CGSize
        let absPos: CGPoint // Menggunakan posisi absolut di map 2000x2000
    }
    var obstacles: [Obstacle] = []
    let playerRadius: CGFloat = 15
    
    // MARK: - Candle-Light Overlay
    var candleLight: CandleLight?
    
    // MARK: - GameOver UI
    var isGameOver = false
    var gameOverNode: SKNode?
    
    // MARK: - Scene Lifecycle
    
    override func didMove(to view: SKView) {
        // Mengatur warna background area game
        self.backgroundColor = SKColor(red: 0.12, green: 0.14, blue: 0.2, alpha: 1.0)
        
        // 0. Setup kamera terlebih dahulu agar HUD ditambahkan pada kamera
        self.camera = cameraNode
        self.addChild(cameraNode)
        cameraNode.setScale(0.6) // Zoom agar map terasa besar dan bisa bergeser
        
        // 1. Menggambar Lantai Grid Kotak Biasa
        createRegularGrid()
        
        // 2. Membuat Karakter Player
        createPlayer()
        
        // 3. Membuat Analog Joystick
        createJoystick()
        
        // 4. Membuat Objek Interaktif Tantangan (Easel Utama & Lab)
        createInteractiveObject()
        
        // 5. Membuat Objek Interaktif Makanan
        createFoodObject()
        
        // 6. Membuat Rintangan (Dinding dan Koridor Ruangan)
        createObstacles()
        
        // 7. Siapkan antrean tantangan acak & label progres
        challengeQueue = DrawingChallenge.all.shuffled()
        createProgressLabel()
        
        // 8. Membuat Progress Bar Stamina
        createStaminaBar()
        
        // 9. Aktifkan overlay cahaya lilin
        enableCandleLight()
    }
    
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        
        // 1. Gambar ulang grid lantai agar sesuai dengan ukuran map
        createRegularGrid()
        
        // 2. Batasi karakter agar tetap berada di dalam batas map 2000x2000
        if let player = player {
            let newX = max(playerRadius, min(2000.0 - playerRadius, player.position.x))
            let newY = max(playerRadius, min(2000.0 - playerRadius, player.position.y))
            player.position = CGPoint(x: newX, y: newY)
        }
        
        // 3. Reposisi HUD pada kamera karena ukuran layar/viewport berubah
        let w = self.size.width
        let h = self.size.height
        
        if let joystickBase = joystickBase {
            joystickBase.position = CGPoint(x: -w / 2 + joystickRadius + 50, y: -h / 2 + joystickRadius + 70)
        }
        
        if let actionButton = actionButton {
            let btnRadius: CGFloat = 40
            actionButton.position = CGPoint(x: w / 2 - btnRadius - 50, y: -h / 2 + joystickRadius + 70)
        }
        
        if let foodActionButton = foodActionButton {
            let btnRadius: CGFloat = 40
            foodActionButton.position = CGPoint(x: w / 2 - btnRadius - 50, y: -h / 2 + joystickRadius + 70)
        }
        
        if let progressLabel = progressLabel {
            progressLabel.position = CGPoint(x: 0, y: h / 2 - 40)
        }
        
        if let staminaBarContainer = staminaBarContainer {
            staminaBarContainer.position = CGPoint(x: -w / 2 + 20, y: h / 2 - 40)
        }
        
        // 4. Reposisi rintangan (tidak perlu reposisi karena posisi absolut), resize cahaya lilin
        candleLight?.position = CGPoint(x: -w / 2, y: -h / 2)
        candleLight?.resize(to: self.size)
        
        // 5. Reposisi layar Game Over pada kamera
        if let gameOverNode = gameOverNode {
            gameOverNode.position = CGPoint.zero
            if let bg = gameOverNode.childNode(withName: "bg") as? SKShapeNode {
                bg.path = CGPath(rect: CGRect(x: -w/2, y: -h/2, width: w, height: h), transform: nil)
            }
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        guard !isGameOver else { return }
        
        // Prioritas pergerakan
        if pencilTarget != nil {
            movePlayerTowardTarget()
        } else if isJoystickActive && joystickVector != CGPoint.zero {
            movePlayer()
        }
        
        // Pengurangan stamina konstan setiap update jika tidak dijeda
        if !self.isPaused {
            stamina = max(0, stamina - staminaDecayRate)
            updateStaminaBarFill()
            
            if stamina <= 0 {
                triggerGameOver()
            }
        }
        
        checkProximityToInteractiveObject()
        checkProximityToFoodObject()
        
        // Perbarui pencahayaan lilin relatif terhadap kamera (player selalu di tengah screen)
        candleLight?.update(lightPosition: CGPoint(x: self.size.width / 2, y: self.size.height / 2), currentTime: currentTime)
        
        // Kamera mengikuti pergerakan player
        cameraNode.position = player.position
    }
}
