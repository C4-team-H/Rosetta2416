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
    /// menyesuaikan lebar & tinggi layar (Scene size).
    func createRegularGrid() {
        gridContainer?.removeFromParent()
        
        let container = SKNode()
        gridContainer = container
        self.addChild(container)
        
        let tileSize: CGFloat = 60 // Ukuran tiap petak grid lantai
        let cols = Int(ceil(self.size.width / tileSize))
        let rows = Int(ceil(self.size.height / tileSize))
        
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
    func createPlayer() {
        player = SKShapeNode(circleOfRadius: 15)
        player.fillColor = SKColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0) // Merah menyala
        player.strokeColor = .white
        player.lineWidth = 2.0
        player.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2) // Mulai di tengah layar
        player.zPosition = 1
        self.addChild(player)
    }
    
    /// Membuat struktur analog joystick visual di pojok kiri bawah layar.
    func createJoystick() {
        // Alas Joystick (lingkaran luar abu-abu semi transparan)
        joystickBase = SKShapeNode(circleOfRadius: joystickRadius)
        joystickBase.position = CGPoint(x: joystickRadius + 50, y: joystickRadius + 70)
        joystickBase.fillColor = SKColor.black.withAlphaComponent(0.2)
        joystickBase.strokeColor = SKColor.white.withAlphaComponent(0.6)
        joystickBase.lineWidth = 3
        joystickBase.zPosition = 10
        self.addChild(joystickBase)
        
        // Tombol Joystick (knob lingkaran putih di dalam yang bisa digeser)
        joystickKnob = SKShapeNode(circleOfRadius: 25)
        joystickKnob.position = CGPoint.zero
        joystickKnob.fillColor = SKColor.white.withAlphaComponent(0.8)
        joystickKnob.strokeColor = .clear
        joystickKnob.zPosition = 11
        joystickBase.addChild(joystickKnob)
    }
    
    /// Membuat objek interaktif Easel Lukisan utama (Tantangan Gambar).
    /// Berwarna kayu coklat, memiliki kanvas putih di tengah, dan lingkaran cahaya (glow) hijau berdenyut.
    func createInteractiveObject() {
        interactiveObject = SKShapeNode(rectOf: CGSize(width: 50, height: 40), cornerRadius: 8)
        interactiveObject.fillColor = SKColor(red: 0.82, green: 0.55, blue: 0.28, alpha: 1.0) // Warna kayu
        interactiveObject.strokeColor = .white
        interactiveObject.lineWidth = 2.0
        interactiveObject.position = CGPoint(x: self.size.width / 2, y: self.size.height * 0.8) // Di bagian atas layar
        interactiveObject.zPosition = 2
        self.addChild(interactiveObject)
        
        // Kanvas putih mini di tengah papan
        let canvasInner = SKShapeNode(rectOf: CGSize(width: 36, height: 28), cornerRadius: 4)
        canvasInner.fillColor = .white
        canvasInner.strokeColor = .clear
        canvasInner.position = CGPoint.zero
        canvasInner.zPosition = 3
        interactiveObject.addChild(canvasInner)
        
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
        
        interactiveObject.addChild(glow)
    }
    
    /// Membuat objek interaktif Makanan (Food Easel).
    /// Berwarna kayu jingga dengan ikon donat lingkaran di kanvas putihnya, memancarkan cahaya oranye berdenyut.
    func createFoodObject() {
        foodObject = SKShapeNode(rectOf: CGSize(width: 50, height: 40), cornerRadius: 8)
        foodObject.fillColor = SKColor(red: 0.9, green: 0.5, blue: 0.15, alpha: 1.0) // Jingga kayu
        foodObject.strokeColor = .white
        foodObject.lineWidth = 2.0
        foodObject.position = CGPoint(x: self.size.width * 0.2, y: self.size.height * 0.3) // Di bagian kiri bawah
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
    
    /// Membuat daftar rintangan (obstacles) statis seperti batu besar, boulder bulat, dan pohon.
    /// Menggunakan rasio posisi relatif agar fleksibel saat orientasi layar berganti.
    func createObstacles() {
        for o in obstacles { o.node.removeFromParent() }
        obstacles.removeAll()
        
        struct Def {
            let relX: CGFloat
            let relY: CGFloat
            let size: CGSize
            let fill: SKColor
            let stroke: SKColor
            let shape: String
        }
        let defs: [Def] = [
            // Batu besar kiri-atas
            Def(relX: 0.22, relY: 0.64, size: CGSize(width: 64, height: 48),
                fill: SKColor(red: 0.45, green: 0.47, blue: 0.52, alpha: 1.0),
                stroke: SKColor(red: 0.28, green: 0.30, blue: 0.35, alpha: 1.0), shape: "rect"),
            // Boulder kanan-atas
            Def(relX: 0.78, relY: 0.60, size: CGSize(width: 56, height: 56),
                fill: SKColor(red: 0.42, green: 0.44, blue: 0.50, alpha: 1.0),
                stroke: SKColor(red: 0.26, green: 0.28, blue: 0.33, alpha: 1.0), shape: "circle"),
            // Blok kiri-bawah
            Def(relX: 0.28, relY: 0.30, size: CGSize(width: 60, height: 60),
                fill: SKColor(red: 0.38, green: 0.42, blue: 0.50, alpha: 1.0),
                stroke: SKColor(red: 0.22, green: 0.26, blue: 0.34, alpha: 1.0), shape: "rect"),
            // Pohon kanan-bawah (grup: kanopy hijau + batang coklat)
            Def(relX: 0.74, relY: 0.32, size: CGSize(width: 70, height: 70),
                fill: SKColor(red: 0.20, green: 0.55, blue: 0.30, alpha: 1.0),
                stroke: SKColor(red: 0.12, green: 0.40, blue: 0.20, alpha: 1.0), shape: "tree"),
            // Dinding horizontal di tengah-atas (antara player & easel)
            Def(relX: 0.50, relY: 0.70, size: CGSize(width: 140, height: 26),
                fill: SKColor(red: 0.33, green: 0.36, blue: 0.42, alpha: 1.0),
                stroke: SKColor(red: 0.20, green: 0.22, blue: 0.28, alpha: 1.0), shape: "rect"),
            // Batu kecil kiri-tengah
            Def(relX: 0.14, relY: 0.48, size: CGSize(width: 44, height: 44),
                fill: SKColor(red: 0.48, green: 0.50, blue: 0.55, alpha: 1.0),
                stroke: SKColor(red: 0.30, green: 0.32, blue: 0.38, alpha: 1.0), shape: "circle")
        ]
        
        for def in defs {
            let node: SKNode
            switch def.shape {
            case "circle":
                let r = min(def.size.width, def.size.height) / 2
                let s = SKShapeNode(circleOfRadius: r)
                s.fillColor = def.fill
                s.strokeColor = def.stroke
                s.lineWidth = 2.0
                node = s
            case "tree":
                let group = SKNode()
                let canopy = SKShapeNode(circleOfRadius: def.size.width / 2)
                canopy.fillColor = def.fill
                canopy.strokeColor = def.stroke
                canopy.lineWidth = 2.0
                canopy.position = CGPoint.zero
                group.addChild(canopy)
                let trunk = SKShapeNode(rectOf: CGSize(width: 14, height: 22), cornerRadius: 3)
                trunk.fillColor = SKColor(red: 0.45, green: 0.30, blue: 0.18, alpha: 1.0)
                trunk.strokeColor = .clear
                trunk.position = CGPoint(x: 0, y: -def.size.height / 2 + 8)
                group.addChild(trunk)
                node = group
            default:
                let s = SKShapeNode(rectOf: def.size, cornerRadius: 8)
                s.fillColor = def.fill
                s.strokeColor = def.stroke
                s.lineWidth = 2.0
                node = s
            }
            node.zPosition = 2
            node.position = CGPoint(x: def.relX * self.size.width,
                                    y: def.relY * self.size.height)
            self.addChild(node)
            obstacles.append(Obstacle(node: node, relX: def.relX, relY: def.relY, size: def.size))
        }
    }
    
    /// Mengatur ulang posisi rintangan visual ketika ukuran layar perangkat berubah (misal rotasi landscape/portrait).
    func repositionObstacles() {
        for o in obstacles {
            o.node.position = CGPoint(x: o.relX * self.size.width,
                                      y: o.relY * self.size.height)
        }
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
        label.position = CGPoint(x: self.size.width / 2, y: self.size.height - 40)
        updateProgressLabel(label)
        self.addChild(label)
        progressLabel = label
    }
    
    /// Memperbarui isi teks label progres ronde.
    func updateProgressLabel(_ label: SKLabelNode) {
        label.text = "TANTANGAN: \(challengesCompleted)/\(totalChallenges)"
    }
    
    /// Membuat komponen HUD Progress Bar untuk menampilkan status stamina pemain secara visual di pojok kiri atas.
    func createStaminaBar() {
        staminaBarContainer?.removeFromParent()
        
        let container = SKNode()
        staminaBarContainer = container
        container.position = CGPoint(x: 20, y: self.size.height - 40)
        container.zPosition = 15
        self.addChild(container)
        
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
    /// Warna disesuaikan otomatis: Hijau (>50%), Oranye (20%-50%), dan Merah (<20%).
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
        light.update(lightPosition: player.position)
        self.addChild(light)
        candleLight = light
    }
}
