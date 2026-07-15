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
        let cols = Int(ceil(2000.0 / tileSize))
        let rows = Int(ceil(2000.0 / tileSize))
        
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
        player.position = CGPoint(x: 375, y: 1000) // Mulai di Sleeping Room
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
        
        // 1. Easel di Engine Room (Center)
        let easelEngine = createEasel(at: CGPoint(x: 1000, y: 1000))
        easelEngine.name = "easel_engine"
        self.addChild(easelEngine)
        challengeEasels.append(easelEngine)
        
        // 2. Tiga Easel di Lab (Top-Left)
        // Ditempatkan agar membentuk segitiga simetris di dalam ruangan Lab
        let easelButterfly = createEasel(at: CGPoint(x: 300, y: 1620))
        easelButterfly.name = "easel_lab_butterfly"
        self.addChild(easelButterfly)
        challengeEasels.append(easelButterfly)
        
        let easelSpider = createEasel(at: CGPoint(x: 375, y: 1680))
        easelSpider.name = "easel_lab_spider"
        self.addChild(easelSpider)
        challengeEasels.append(easelSpider)
        
        let easelSnake = createEasel(at: CGPoint(x: 450, y: 1620))
        easelSnake.name = "easel_lab_snake"
        self.addChild(easelSnake)
        challengeEasels.append(easelSnake)
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
        foodObject.position = CGPoint(x: 1625, y: 400) // Di Kitchen
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
        
        // 1. Dinding Sleeping Room (Kiri / Spawn)
        // minX = 200, maxX = 550, minY = 825, maxY = 1175
        // Pintu kanan: Y [950, 1050]
        addWall(from: CGPoint(x: 200, y: 825), to: CGPoint(x: 200, y: 1175)) // Kiri
        addWall(from: CGPoint(x: 200, y: 1175), to: CGPoint(x: 550, y: 1175)) // Atas
        addWall(from: CGPoint(x: 200, y: 825), to: CGPoint(x: 550, y: 825)) // Bawah
        addWall(from: CGPoint(x: 550, y: 825), to: CGPoint(x: 550, y: 950)) // Kanan bawah
        addWall(from: CGPoint(x: 550, y: 1050), to: CGPoint(x: 550, y: 1175)) // Kanan atas
        addRoomLabel(text: "SLEEPING ROOM", position: CGPoint(x: 375, y: 1000))
        
        // 2. Dinding Engine Room (Tengah)
        // minX = 800, maxX = 1200, minY = 800, maxY = 1200
        // Pintu kiri: Y [950, 1050]
        // Pintu atas: X [950, 1050]
        // Pintu bawah: X [950, 1050]
        addWall(from: CGPoint(x: 800, y: 800), to: CGPoint(x: 800, y: 950)) // Kiri bawah
        addWall(from: CGPoint(x: 800, y: 1050), to: CGPoint(x: 800, y: 1200)) // Kiri atas
        addWall(from: CGPoint(x: 1200, y: 800), to: CGPoint(x: 1200, y: 1200)) // Kanan
        addWall(from: CGPoint(x: 800, y: 1200), to: CGPoint(x: 950, y: 1200)) // Atas kiri
        addWall(from: CGPoint(x: 1050, y: 1200), to: CGPoint(x: 1200, y: 1200)) // Atas kanan
        addWall(from: CGPoint(x: 800, y: 800), to: CGPoint(x: 950, y: 800)) // Bawah kiri
        addWall(from: CGPoint(x: 1050, y: 800), to: CGPoint(x: 1200, y: 800)) // Bawah kanan
        addRoomLabel(text: "ENGINE ROOM", position: CGPoint(x: 1000, y: 1000))
        
        // 3. Dinding Lab (Atas Kiri)
        // minX = 200, maxX = 550, minY = 1425, maxY = 1775
        // Pintu bawah: X [325, 425]
        addWall(from: CGPoint(x: 200, y: 1425), to: CGPoint(x: 200, y: 1775)) // Kiri
        addWall(from: CGPoint(x: 200, y: 1775), to: CGPoint(x: 550, y: 1775)) // Atas
        addWall(from: CGPoint(x: 550, y: 1425), to: CGPoint(x: 550, y: 1775)) // Kanan
        addWall(from: CGPoint(x: 200, y: 1425), to: CGPoint(x: 325, y: 1425)) // Bawah kiri
        addWall(from: CGPoint(x: 425, y: 1425), to: CGPoint(x: 550, y: 1425)) // Bawah kanan
        addRoomLabel(text: "LAB", position: CGPoint(x: 375, y: 1600))
        
        // 4. Dinding Kitchen (Bawah Kanan)
        // minX = 1450, maxX = 1800, minY = 225, maxY = 575
        // Pintu kiri: Y [350, 450]
        addWall(from: CGPoint(x: 1800, y: 225), to: CGPoint(x: 1800, y: 575)) // Kanan
        addWall(from: CGPoint(x: 1450, y: 575), to: CGPoint(x: 1800, y: 575)) // Atas
        addWall(from: CGPoint(x: 1450, y: 225), to: CGPoint(x: 1800, y: 225)) // Bawah
        addWall(from: CGPoint(x: 1450, y: 225), to: CGPoint(x: 1450, y: 350)) // Kiri bawah
        addWall(from: CGPoint(x: 1450, y: 450), to: CGPoint(x: 1450, y: 575)) // Kiri atas
        addRoomLabel(text: "KITCHEN", position: CGPoint(x: 1625, y: 400))
        
        // 5. Koridor Sleeping Room ke Engine Room
        addWall(from: CGPoint(x: 550, y: 1050), to: CGPoint(x: 800, y: 1050)) // Atas
        addWall(from: CGPoint(x: 550, y: 950), to: CGPoint(x: 800, y: 950)) // Bawah
        
        // 6. Koridor Lab ke Engine Room (L-shaped)
        addWall(from: CGPoint(x: 325, y: 1425), to: CGPoint(x: 325, y: 1250))
        addWall(from: CGPoint(x: 325, y: 1250), to: CGPoint(x: 950, y: 1250))
        addWall(from: CGPoint(x: 950, y: 1250), to: CGPoint(x: 950, y: 1200))
        
        addWall(from: CGPoint(x: 425, y: 1425), to: CGPoint(x: 425, y: 1350))
        addWall(from: CGPoint(x: 425, y: 1350), to: CGPoint(x: 1050, y: 1350))
        addWall(from: CGPoint(x: 1050, y: 1350), to: CGPoint(x: 1050, y: 1200))
        
        // 7. Koridor Kitchen ke Engine Room (L-shaped)
        addWall(from: CGPoint(x: 1450, y: 450), to: CGPoint(x: 1050, y: 450))
        addWall(from: CGPoint(x: 1050, y: 450), to: CGPoint(x: 1050, y: 800))
        
        addWall(from: CGPoint(x: 1450, y: 350), to: CGPoint(x: 950, y: 350))
        addWall(from: CGPoint(x: 950, y: 350), to: CGPoint(x: 950, y: 800))
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
    
    /// Membuat komponen HUD Progress Bar untuk menampilkan status kemajuan AI Intelligence secara visual di pojok kanan atas.
    func createAiIntelligenceBar() {
        aiIntelligenceBarContainer?.removeFromParent()
        
        let container = SKNode()
        aiIntelligenceBarContainer = container
        let w = self.size.width
        let h = self.size.height
        container.position = CGPoint(x: w / 2 - 200, y: h / 2 - 40)
        container.zPosition = 15
        cameraNode.addChild(container)
        
        // Teks "AI INTELLIGENCE" di atas bar
        let label = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        label.text = "AI INTELLIGENCE"
        label.fontSize = 11
        label.fontColor = SKColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 1.0)
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
        
        updateAiIntelligenceBarFill()
    }
    
    /// Memperbarui lebar dan persentase teks isi dari progress bar AI Intelligence.
    func updateAiIntelligenceBarFill() {
        guard let container = aiIntelligenceBarContainer else { return }
        
        container.childNode(withName: "aiFillBar")?.removeFromParent()
        container.childNode(withName: "aiPercentLabel")?.removeFromParent()
        
        let fillWidth = 150 * (aiIntelligence / maxAiIntelligence)
        
        if fillWidth > 0 {
            let fillBar = SKShapeNode(rect: CGRect(x: 0, y: -6, width: fillWidth, height: 12), cornerRadius: 6)
            fillBar.fillColor = SKColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0) // Cyan/Blue
            fillBar.strokeColor = .clear
            fillBar.name = "aiFillBar"
            container.addChild(fillBar)
        }
        
        let percentLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        percentLabel.text = "\(Int(round(aiIntelligence)))%"
        percentLabel.fontSize = 11
        percentLabel.fontColor = .white
        percentLabel.position = CGPoint(x: 160, y: -4)
        percentLabel.horizontalAlignmentMode = .left
        percentLabel.verticalAlignmentMode = .bottom
        percentLabel.name = "aiPercentLabel"
        container.addChild(percentLabel)
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
    
    /// Mengaktifkan efek atmosferik overlay cahaya lilin hangat yang membatasi penglihatan layar luar (kegelapan).
    func enableCandleLight() {
        candleLight?.removeFromParent()
        let configuration = CandleLight.Configuration(
            radius: 180.0,
            darknessOpacity: 0.94,
            lightIntensity: 1.0,
            softness: 0.42,
            verticalScale: 1.08,
            warmth: 0.08,
            flickerAmount: 0.025,
            flickerSpeed: 1.0
        )
        let light = CandleLight(sceneSize: self.size, configuration: configuration)
        light.zPosition = 9.5
        light.position = CGPoint(x: -self.size.width / 2, y: -self.size.height / 2)
        light.update(lightPosition: CGPoint(x: self.size.width / 2, y: self.size.height / 2))
        cameraNode.addChild(light)
        candleLight = light
    }
}
