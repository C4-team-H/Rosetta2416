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
        let relX: CGFloat
        let relY: CGFloat
        let size: CGSize
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
        
        // 1. Menggambar Lantai Grid Kotak Biasa
        createRegularGrid()
        
        // 2. Membuat Karakter Player
        createPlayer()
        
        // 3. Membuat Analog Joystick
        createJoystick()
        
        // 4. Membuat Objek Interaktif Tantangan (Easel Utama)
        createInteractiveObject()
        
        // 5. Membuat Objek Interaktif Makanan
        createFoodObject()
        
        // 6. Membuat Rintangan
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
        
        // 1. Gambar ulang grid lantai agar sesuai dengan ukuran layar yang baru
        createRegularGrid()
        
        // 2. Batasi karakter agar tetap berada di dalam layar baru (tidak terlempar keluar layar)
        if let player = player {
            let newX = max(playerRadius, min(self.size.width - playerRadius, player.position.x))
            let newY = max(playerRadius, min(self.size.height - playerRadius, player.position.y))
            player.position = CGPoint(x: newX, y: newY)
        }
        
        // 3. Pastikan joystick tetap berada di pojok kiri bawah layar yang baru
        if let joystickBase = joystickBase {
            joystickBase.position = CGPoint(x: joystickRadius + 50, y: joystickRadius + 70)
        }
        
        // 4. Reposisi objek interaktif easel utama
        if let interactiveObject = interactiveObject {
            interactiveObject.position = CGPoint(x: self.size.width / 2, y: self.size.height * 0.8)
        }
        
        // 5. Reposisi tombol aksi jika sedang aktif
        if let actionButton = actionButton {
            let btnRadius: CGFloat = 40
            actionButton.position = CGPoint(x: self.size.width - btnRadius - 50, y: joystickRadius + 70)
        }
        
        // 6. Reposisi objek interaktif makanan
        if let foodObject = foodObject {
            foodObject.position = CGPoint(x: self.size.width * 0.2, y: self.size.height * 0.3)
        }
        
        // 7. Reposisi tombol makan jika sedang aktif
        if let foodActionButton = foodActionButton {
            let btnRadius: CGFloat = 40
            foodActionButton.position = CGPoint(x: self.size.width - btnRadius - 50, y: joystickRadius + 70)
        }
        
        // 8. Reposisi label progres ronde
        if let progressLabel = progressLabel {
            progressLabel.position = CGPoint(x: self.size.width / 2, y: self.size.height - 40)
        }
        
        // 9. Reposisi progress bar stamina
        if let staminaBarContainer = staminaBarContainer {
            staminaBarContainer.position = CGPoint(x: 20, y: self.size.height - 40)
        }
        
        // 10. Reposisi rintangan & resize cahaya
        repositionObstacles()
        candleLight?.resize(to: self.size)
        
        // 11. Reposisi layar Game Over
        if let gameOverNode = gameOverNode {
            gameOverNode.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2)
            if let bg = gameOverNode.childNode(withName: "bg") as? SKShapeNode {
                bg.path = CGPath(rect: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height), transform: nil)
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
        
        candleLight?.update(lightPosition: player.position, currentTime: currentTime)
    }
}
