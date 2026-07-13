//
//  MainMenuScene.swift
//  GameClassification
//
//  Created by Muhammad Muthi' Nuritzan on 13/07/26.
//

import SpriteKit

class MainMenuScene: SKScene {
    
    private var titleLabel: SKLabelNode!
    private var startButton: SKShapeNode!
    
    override func didMove(to view: SKView) {
        // 1. Mengatur warna background menu utama
        self.backgroundColor = SKColor(red: 0.1, green: 0.12, blue: 0.18, alpha: 1.0) // Slate dark blue
        
        // 2. Membuat Label Judul Game
        titleLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        titleLabel.text = "DRAWING SPACE"
        titleLabel.fontSize = 36
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: self.size.width / 2, y: self.size.height * 0.6)
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .center
        self.addChild(titleLabel)
        
        // 3. Membuat Tombol Start Game (Menggunakan ShapeNode berbentuk rounded rect)
        let buttonWidth: CGFloat = 200
        let buttonHeight: CGFloat = 60
        startButton = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 12)
        startButton.name = "startButton"
        startButton.position = CGPoint(x: self.size.width / 2, y: self.size.height * 0.4)
        startButton.fillColor = SKColor(red: 0.15, green: 0.68, blue: 0.38, alpha: 1.0) // Vibrant green
        startButton.strokeColor = .white
        startButton.lineWidth = 2
        
        // 4. Menambahkan teks di dalam tombol Start
        let startLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        startLabel.text = "START GAME"
        startLabel.fontSize = 20
        startLabel.fontColor = .white
        startLabel.name = "startButton" // Nama harus sama agar klik di bagian teks juga dideteksi
        startLabel.horizontalAlignmentMode = .center
        startLabel.verticalAlignmentMode = .center
        
        // Memasukkan teks sebagai child dari tombol agar posisinya relatif terhadap tombol
        startButton.addChild(startLabel)
        self.addChild(startButton)
    }
    
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        
        if titleLabel != nil {
            titleLabel.position = CGPoint(x: self.size.width / 2, y: self.size.height * 0.6)
        }
        if startButton != nil {
            startButton.position = CGPoint(x: self.size.width / 2, y: self.size.height * 0.4)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodesAtPoint = self.nodes(at: location)
        
        // 5. Cek apakah pengguna mengklik node bernama "startButton"
        for node in nodesAtPoint {
            if node.name == "startButton" {
                startGame()
                break
            }
        }
    }
    
    private func startGame() {
        // 6. Transisi ke GameScene secara programmatic
        let gameScene = GameScene(size: self.size)
        gameScene.scaleMode = .resizeFill
        
        // Efek transisi pudar (fade) selama 1 detik
        let transition = SKTransition.fade(withDuration: 1.0)
        self.view?.presentScene(gameScene, transition: transition)
    }
}
