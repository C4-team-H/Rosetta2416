//
//  GameScene+Setup.swift
//  GameClassification
//
//  Created by Muhammad Muthi' Nuritzan on 14/07/26.
//

import SpriteKit

// Extension ini khusus menangani pembuatan (setup) dan penempatan awal seluruh objek visual
// serta HUD di dalam arena permainan (Scene).
extension GameScene {
    
    /// Menggambar lantai bermotif papan catur (checkerboard grid) secara dinamis
    /// mencakup area map sebesar 2000x2000.
    func createRegularGrid() {
        gridContainer?.removeFromParent()
        
        let container = SKNode()
        gridContainer = container
        self.addChild(container)
        
        let tileSize: CGFloat = 60 // Ukuran tiap petak grid lantai
        let cols = Int(ceil(GameMapLayout.worldSize.width / tileSize))
        let rows = Int(ceil(GameMapLayout.worldSize.height / tileSize))
        
        for row in 0..<rows {
            for col in 0..<cols {
                let xPos = CGFloat(col) * tileSize + tileSize / 2
                let yPos = CGFloat(row) * tileSize + tileSize / 2
                
                let tile = SKShapeNode(rectOf: CGSize(width: tileSize, height: tileSize))
                tile.position = CGPoint(x: xPos, y: yPos)
                
                // Selang-seling warna gelap-terang agar terlihat estetik
                tile.fillColor = (row + col) % 2 == 0 ?
                    SKColor(red: 0.18, green: 0.22, blue: 0.3, alpha: 1.0) :
                    SKColor(red: 0.15, green: 0.18, blue: 0.25, alpha: 1.0)
                tile.strokeColor = SKColor(red: 0.25, green: 0.3, blue: 0.4, alpha: 1.0)
                tile.lineWidth = 1.0
                tile.zPosition = -1 // Selalu di belakang agar tidak menutupi player/easel
                
                container.addChild(tile)
            }
        }
    }
    
    /// Membuat node karakter utama (player) berbentuk lingkaran merah dengan radius 15.
    /// Karakter di-spawn di Sleeping Room (Kiri).
    func createPlayer() {
        player = SKShapeNode(circleOfRadius: 15)
        player.fillColor = SKColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0) // Merah menyala
        player.strokeColor = .white
        player.lineWidth = 2.0
        player.position = GameMapLayout.playerSpawnPosition
        player.zPosition = 1
        self.addChild(player)
    }
    
    /// Membuat struktur analog joystick visual sebagai anak dari cameraNode.
    func createJoystick() {
        // Alas Joystick (lingkaran luar abu-abu semi transparan)
        joystickBase = SKShapeNode(circleOfRadius: joystickRadius)
        let w = self.size.width
        let h = self.size.height
        joystickBase.position = CGPoint(x: -w / 2 + joystickRadius + 50, y: -h / 2 + joystickRadius + 70)
        joystickBase.fillColor = SKColor.black.withAlphaComponent(0.2)
        joystickBase.strokeColor = SKColor.white.withAlphaComponent(0.6)
        joystickBase.lineWidth = 3
        joystickBase.zPosition = 10
        cameraNode.addChild(joystickBase)
        
        // Tombol Joystick (knob lingkaran putih di dalam yang bisa digeser)
        joystickKnob = SKShapeNode(circleOfRadius: 25)
        joystickKnob.position = CGPoint.zero
        joystickKnob.fillColor = SKColor.white.withAlphaComponent(0.8)
        joystickKnob.strokeColor = .clear
        joystickKnob.zPosition = 11
        joystickBase.addChild(joystickKnob)
    }
    
    /// Membuat objek interaktif Easel Lukisan tantangan gambar di Engine Room dan Lab.
    func createInteractiveObject() {
        challengeEasels.forEach { $0.removeFromParent() }
        challengeEasels.removeAll()
        labEaselChallengesMap.removeAll()
        
        var labEaselIndex = 0
        for position in GameMapLayout.challengeStationPositions {
            let easel = createEasel(at: position)
            
            if position.y > 1300 {
                // Lab easel: assign name + fixed challenge
                let name = "labEasel_\(labEaselIndex)"
                easel.name = name
                labEaselChallengesMap[name] = DrawingChallenge.labEaselChallenges[labEaselIndex]
                labEaselIndex += 1
            } else {
                // Engine easel
                easel.name = "engineEasel"
            }
            
            addChild(easel)
            challengeEasels.append(easel)
        }
    }
    
    /// Helper untuk membuat satu easel papan gambar tantangan.
    private func createEasel(at pos: CGPoint) -> SKShapeNode {
        let easel = SKShapeNode(rectOf: CGSize(width: 50, height: 40), cornerRadius: 8)
        easel.fillColor = SKColor(red: 0.82, green: 0.55, blue: 0.28, alpha: 1.0) // Warna kayu
        easel.strokeColor = .white
        easel.lineWidth = 2.0
        easel.position = pos
        easel.zPosition = 2
        
        // Kanvas putih mini di tengah papan
        let canvasInner = SKShapeNode(rectOf: CGSize(width: 36, height: 28), cornerRadius: 4)
        canvasInner.fillColor = .white
        canvasInner.strokeColor = .clear
        canvasInner.position = CGPoint.zero
        canvasInner.zPosition = 3
        easel.addChild(canvasInner)
        
        // Simbol goresan kuas (garis diagonal hitam)
        let line = SKShapeNode(rectOf: CGSize(width: 22, height: 4), cornerRadius: 1)
        line.fillColor = .black
        line.strokeColor = .clear
        line.zRotation = CGFloat.pi / 4
        line.position = CGPoint.zero
        line.zPosition = 4
        canvasInner.addChild(line)
        
        // Cahaya hijau (glow) berdenyut menandakan objek interaktif utama
        let glow = SKShapeNode(circleOfRadius: 45)
        glow.strokeColor = SKColor(red: 0.15, green: 0.68, blue: 0.38, alpha: 0.4)
        glow.lineWidth = 2.0
        glow.zPosition = 1
        
        let scaleUp = SKAction.scale(to: 1.25, duration: 1.2)
        let scaleDown = SKAction.scale(to: 0.85, duration: 1.2)
        let pulse = SKAction.repeatForever(SKAction.sequence([scaleUp, scaleDown]))
        glow.run(pulse)
        
        easel.addChild(glow)
        return easel
    }
    
    /// Membuat objek interaktif Makanan (Food Easel) di Kitchen (Bawah Kanan).
    func createFoodObject() {
        foodObject?.removeFromParent()
        
        foodObject = SKShapeNode(rectOf: CGSize(width: 50, height: 40), cornerRadius: 8)
        foodObject.fillColor = SKColor(red: 0.9, green: 0.5, blue: 0.15, alpha: 1.0) // Jingga kayu
        foodObject.strokeColor = .white
        foodObject.lineWidth = 2.0
        foodObject.position = GameMapLayout.foodStationPosition
        foodObject.zPosition = 2
        self.addChild(foodObject)
        
        let canvasInner = SKShapeNode(rectOf: CGSize(width: 36, height: 28), cornerRadius: 4)
        canvasInner.fillColor = .white
        canvasInner.strokeColor = .clear
        canvasInner.position = CGPoint.zero
        canvasInner.zPosition = 3
        foodObject.addChild(canvasInner)
        
        // Simbol donat (lingkaran oranye berlubang)
        let donutShape = SKShapeNode(circleOfRadius: 6)
        donutShape.fillColor = .clear
        donutShape.strokeColor = .orange
        donutShape.lineWidth = 4.0
        donutShape.position = CGPoint.zero
        donutShape.zPosition = 4
        canvasInner.addChild(donutShape)
        
        // Cahaya oranye (glow) berdenyut untuk stasiun pengisian energi
        let glow = SKShapeNode(circleOfRadius: 45)
        glow.strokeColor = SKColor(red: 0.9, green: 0.5, blue: 0.15, alpha: 0.4)
        glow.lineWidth = 2.0
        glow.zPosition = 1
        
        let scaleUp = SKAction.scale(to: 1.25, duration: 1.2)
        let scaleDown = SKAction.scale(to: 0.85, duration: 1.2)
        let pulse = SKAction.repeatForever(SKAction.sequence([scaleUp, scaleDown]))
        glow.run(pulse)
        
        foodObject.addChild(glow)
    }
    
    /// Membuat dinding-dinding dan koridor untuk 4 ruangan: Sleeping Room, Engine Room, Kitchen, dan Lab.
    func createObstacles() {
        for o in obstacles { o.node.removeFromParent() }
        obstacles.removeAll()
        
        // Hapus label ruangan lama agar tidak bertumpuk jika digambar ulang
        self.children.filter { $0.name == "roomLabel" }.forEach { $0.removeFromParent() }

        for wall in GameMapLayout.wallSegments {
            addWall(from: wall.start, to: wall.end)
        }

        for room in GameMapLayout.rooms {
            addRoomLabel(
                text: room.name,
                position: CGPoint(x: room.worldFrame.midX, y: room.worldFrame.midY)
            )
        }
    }
    
    /// Helper untuk menambahkan dinding solid (Obstacle) berbentuk garis lurus tebal.
    private func addWall(from p1: CGPoint, to p2: CGPoint) {
        let thickness: CGFloat = 16.0
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        let length = sqrt(dx*dx + dy*dy)
        guard length > 0 else { return }
        
        let isHorizontal = abs(dx) > abs(dy)
        let size = isHorizontal ? CGSize(width: length, height: thickness) : CGSize(width: thickness, height: length)
        let px = (p1.x + p2.x) / 2
        let py = (p1.y + p2.y) / 2
        
        let wallNode = SKShapeNode(rectOf: size, cornerRadius: 4)
        wallNode.position = CGPoint(x: px, y: py)
        wallNode.fillColor = SKColor(red: 0.28, green: 0.30, blue: 0.38, alpha: 1.0) // Slate gray wall
        wallNode.strokeColor = SKColor(red: 0.40, green: 0.45, blue: 0.55, alpha: 1.0)
        wallNode.lineWidth = 1.5
        wallNode.zPosition = 2
        
        self.addChild(wallNode)
        
        let obstacle = Obstacle(node: wallNode, size: size, absPos: CGPoint(x: px, y: py))
        obstacles.append(obstacle)
    }
    
    /// Helper untuk menambahkan teks label nama ruangan di lantai.
    private func addRoomLabel(text: String, position: CGPoint) {
        let label = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        label.text = text
        label.fontSize = 20
        label.fontColor = SKColor.white.withAlphaComponent(0.15)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = position
        label.zPosition = 0
        label.name = "roomLabel"
        self.addChild(label)
    }
    
    /// Dinding saat ini bersifat absolut dan permanen di peta 2000x2000, tidak perlu reposisi dinamis.
    func repositionObstacles() {
        // Sengaja dibiarkan kosong karena dinding bernilai absolut
    }
    
    /// Membuat label petunjuk progres tantangan menggambar ("TANTANGAN: X/5") di bagian atas tengah layar.
    func createProgressLabel() {
        progressLabel?.removeFromParent()
        
        let label = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        label.fontSize = 18
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.zPosition = 15
        label.position = CGPoint(x: 0, y: self.size.height / 2 - 40)
        updateProgressLabel(label)
        cameraNode.addChild(label)
        progressLabel = label
    }
    
    /// Memperbarui isi teks label progres ronde.
    func updateProgressLabel(_ label: SKLabelNode) {
        label.text = "ENGINE: \(engineChallengesCompleted)/5 | LAB: \(labChallengesCompleted)/3"
    }
    
    /// Membuat komponen HUD Progress Bar untuk menampilkan status stamina pemain secara visual di pojok kiri atas.
    func createStaminaBar() {
        staminaBarContainer?.removeFromParent()
        
        let container = SKNode()
        staminaBarContainer = container
        let w = self.size.width
        let h = self.size.height
        container.position = CGPoint(x: -w / 2 + 20, y: h / 2 - 40)
        container.zPosition = 15
        cameraNode.addChild(container)
        
        // Teks "ENERGY" di atas bar
        let label = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        label.text = "ENERGY"
        label.fontSize = 11
        label.fontColor = .orange
        label.position = CGPoint(x: 0, y: 10)
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .bottom
        container.addChild(label)
        
        // Bingkai luar bar (border putih, background hitam transparan)
        let bgBar = SKShapeNode(rect: CGRect(x: 0, y: -6, width: 150, height: 12), cornerRadius: 6)
        bgBar.fillColor = SKColor.black.withAlphaComponent(0.4)
        bgBar.strokeColor = .white
        bgBar.lineWidth = 1.5
        container.addChild(bgBar)
        
        updateStaminaBarFill()
    }
    
    /// Memperbarui lebar dan warna isi dari progress bar stamina.
    func updateStaminaBarFill() {
        guard let container = staminaBarContainer else { return }
        
        container.childNode(withName: "fillBar")?.removeFromParent()
        
        let fillWidth = 150 * (stamina / maxStamina)
        guard fillWidth > 0 else { return }
        
        let fillBar = SKShapeNode(rect: CGRect(x: 0, y: -6, width: fillWidth, height: 12), cornerRadius: 6)
        
        if stamina > 50 {
            fillBar.fillColor = SKColor(red: 0.15, green: 0.68, blue: 0.38, alpha: 1.0) // Hijau
        } else if stamina > 20 {
            fillBar.fillColor = SKColor(red: 0.9, green: 0.5, blue: 0.15, alpha: 1.0) // Oranye
        } else {
            fillBar.fillColor = SKColor(red: 0.74, green: 0.25, blue: 0.25, alpha: 1.0) // Merah
        }
        fillBar.strokeColor = .clear
        fillBar.name = "fillBar"
        container.addChild(fillBar)
    }
    
    /// Membuat komponen HUD Progress Bar untuk menampilkan status AI Intelligence pemain secara visual di pojok kanan atas.
    func createAiIntelligenceBar() {
        aiIntelligenceBarContainer?.removeFromParent()
        
        let container = SKNode()
        aiIntelligenceBarContainer = container
        let w = self.size.width
        let h = self.size.height
        container.position = CGPoint(x: w / 2 - 200, y: h / 2 - 40)
        container.zPosition = 15
        cameraNode.addChild(container)
        
        // Teks "AI INTEL" di atas bar
        let label = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        label.text = "AI INTEL"
        label.fontSize = 11
        label.fontColor = SKColor(red: 0.3, green: 0.6, blue: 0.95, alpha: 1.0) // Biru terang
        label.position = CGPoint(x: 0, y: 10)
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .bottom
        container.addChild(label)
        
        // Teks persentase di kanan bar (mis. "10%")
        let percentLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        percentLabel.fontSize = 11
        percentLabel.fontColor = .white
        percentLabel.position = CGPoint(x: 158, y: 10)
        percentLabel.horizontalAlignmentMode = .right
        percentLabel.verticalAlignmentMode = .bottom
        percentLabel.name = "percentLabel"
        container.addChild(percentLabel)
        
        // Bingkai luar bar (border putih, background hitam transparan)
        let bgBar = SKShapeNode(rect: CGRect(x: 0, y: -6, width: 150, height: 12), cornerRadius: 6)
        bgBar.fillColor = SKColor.black.withAlphaComponent(0.4)
        bgBar.strokeColor = .white
        bgBar.lineWidth = 1.5
        container.addChild(bgBar)
        
        updateAiIntelligenceBarFill()
    }
    
    /// Memperbarui lebar dan warna isi dari progress bar AI Intelligence.
    func updateAiIntelligenceBarFill() {
        guard let container = aiIntelligenceBarContainer else { return }
        
        // Update teks persentase
        if let percentLabel = container.childNode(withName: "percentLabel") as? SKLabelNode {
            percentLabel.text = "\(Int(aiIntelligence))%"
        }
        
        container.childNode(withName: "fillBar")?.removeFromParent()
        
        let fillWidth = 150 * (aiIntelligence / maxAiIntelligence)
        guard fillWidth > 0 else { return }
        
        let fillBar = SKShapeNode(rect: CGRect(x: 0, y: -6, width: fillWidth, height: 12), cornerRadius: 6)
        
        if aiIntelligence > 60 {
            fillBar.fillColor = SKColor(red: 0.2, green: 0.7, blue: 1.0, alpha: 1.0) // Cyan terang
        } else if aiIntelligence > 30 {
            fillBar.fillColor = SKColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1.0) // Biru
        } else {
            fillBar.fillColor = SKColor(red: 0.35, green: 0.35, blue: 0.6, alpha: 1.0) // Biru gelap
        }
        fillBar.strokeColor = .clear
        fillBar.name = "fillBar"
        container.addChild(fillBar)
    }
    
    /// Mengaktifkan efek atmosferik overlay cahaya lilin hangat yang membatasi penglihatan layar luar (kegelapan).
    func enableCandleLight() {
        candleLight?.removeFromParent()
        let configuration = CandleLightNode.Configuration(
            radius: 180.0,
            darknessOpacity: 0.94,
            lightIntensity: 1.0,
            softness: 0.42,
            verticalScale: 1.08,
            warmth: 0.08,
            flickerAmount: 0.025,
            flickerSpeed: 1.0
        )
        let light = CandleLightNode(sceneSize: self.size, configuration: configuration)
        light.zPosition = 9.5
        light.position = CGPoint(x: -self.size.width / 2, y: -self.size.height / 2)
        light.update(lightPosition: CGPoint(x: self.size.width / 2, y: self.size.height / 2))
        cameraNode.addChild(light)
        candleLight = light
    }
}
