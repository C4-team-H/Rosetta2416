//
//  GameScene+Movement.swift
//  GameClassification
//
//  Created by Muhammad Muthi' Nuritzan on 14/07/26.
//

import SpriteKit

// Extension ini khusus menangani sistem pergerakan karakter utama (player)
// dan kalkulasi fisika sederhana/tabrakan rintangan.
extension GameScene {
    
    /// Memindahkan player menggunakan input dari Joystick analog jari.
    /// Dipanggil setiap frame pada method `update(_:)` jika joystick aktif.
    func movePlayer() {
        // Karakter tidak boleh bergerak jika Energy habis.
        guard sessionState.energy > 0 else { return }
        
        let jx = joystickVector.x
        let jy = joystickVector.y
        
        // Hitung delta pergerakan berdasarkan joystick vector dan kecepatan playerSpeed
        let dx = jx * playerSpeed
        let dy = jy * playerSpeed
        
        var newPosition = CGPoint(x: player.position.x + dx, y: player.position.y + dy)
        
        let worldSize = GameMapLayout.worldSize
        newPosition.x = max(playerRadius, min(worldSize.width - playerRadius, newPosition.x))
        newPosition.y = max(playerRadius, min(worldSize.height - playerRadius, newPosition.y))
        
        // Deteksi Obstacle: Cek benturan rintangan dengan slide-along physics
        newPosition = attemptMove(to: newPosition)
        
        // Update posisi akhir player
        player.position = newPosition
    }
    
    /// Memindahkan player menuju titik koordinat tujuan Apple Pencil (tap-to-move).
    /// Dipanggil setiap frame pada `update(_:)` jika target navigasi Pencil aktif.
    func movePlayerTowardTarget() {
        guard let target = pencilTarget else { return }
        
        // Hentikan pergerakan jika Energy habis.
        guard sessionState.energy > 0 else {
            pencilTarget = nil
            hideTargetMarker()
            return
        }
        
        let dx = target.x - player.position.x
        let dy = target.y - player.position.y
        let distance = sqrt(dx*dx + dy*dy)
        
        // Jika player sudah sangat dekat dengan target (di bawah threshold), hentikan pergerakan
        if distance <= arrivalThreshold {
            pencilTarget = nil
            hideTargetMarker()
            return
        }
        
        // Hitung langkah pergerakan disesuaikan dengan tekanan Apple Pencil (pencilSpeedMultiplier)
        let step = playerSpeed * pencilSpeedMultiplier
        let nx = dx / distance
        let ny = dy / distance
        
        // Cegah overshoot: jangan melompat melewati target jika jarak sisa lebih kecil dari langkah
        let moveStep = min(step, distance)
        var newPosition = CGPoint(x: player.position.x + nx * moveStep,
                                  y: player.position.y + ny * moveStep)
        
        let worldSize = GameMapLayout.worldSize
        newPosition.x = max(playerRadius, min(worldSize.width - playerRadius, newPosition.x))
        newPosition.y = max(playerRadius, min(worldSize.height - playerRadius, newPosition.y))
        
        // Deteksi Obstacle dengan slide-along physics
        newPosition = attemptMove(to: newPosition)
        
        // Update posisi
        player.position = newPosition
    }
    
    /// Menghitung Bounding Box (Rect) dari rintangan berdasarkan rasio koordinat layar.
    /// - Parameter o: Struct rintangan (Obstacle)
    /// - Returns: CGRect koordinat layar real
    func collisionBox(for o: Obstacle) -> CGRect {
        return CGRect(x: o.absPos.x - o.size.width / 2, y: o.absPos.y - o.size.height / 2,
                      width: o.size.width, height: o.size.height)
    }
    
    /// Memeriksa apakah suatu koordinat titik bersentuhan dengan rintangan mana pun.
    /// Menggunakan metode Circle-vs-Rectangle collision detection.
    /// - Parameter pos: Titik koordinat yang akan dicek
    /// - Returns: true jika menabrak rintangan, false jika aman
    func collidesWithObstacle(at pos: CGPoint) -> Bool {
        let r = playerRadius
        for o in obstacles {
            let rect = collisionBox(for: o)
            // Cari titik terdekat pada persegi rintangan terhadap pusat lingkaran player
            let closestX = max(rect.minX, min(pos.x, rect.maxX))
            let closestY = max(rect.minY, min(pos.y, rect.maxY))
            
            // Hitung jarak dari titik terdekat ke pusat lingkaran player
            let dx = pos.x - closestX
            let dy = pos.y - closestY
            
            // Jika kuadrat jarak kurang dari kuadrat radius player, berarti bertabrakan
            if (dx * dx + dy * dy) < (r * r) {
                return true
            }
        }
        return false
    }
    
    /// Sistem Pergerakan Slide-Along: Mencoba bergerak ke koordinat baru.
    /// Jika menabrak dinding, coba hanya bergerak di sumbu X, jika tidak bisa coba di sumbu Y,
    /// agar karakter "meluncur" halus di sepanjang sisi rintangan daripada menempel kaku.
    /// - Parameter newPos: Posisi target pergerakan
    /// - Returns: CGPoint posisi aman final
    func attemptMove(to newPos: CGPoint) -> CGPoint {
        // Jika posisi tujuan bebas dari tabrakan, langsung izinkan
        if !collidesWithObstacle(at: newPos) {
            return newPos
        }
        
        // Percobaan 1: Coba meluncur horizontal saja (pertahankan koordinat Y lama)
        let xOnly = CGPoint(x: newPos.x, y: player.position.y)
        if !collidesWithObstacle(at: xOnly) {
            return xOnly
        }
        
        // Percobaan 2: Coba meluncur vertikal saja (pertahankan koordinat X lama)
        let yOnly = CGPoint(x: player.position.x, y: newPos.y)
        if !collidesWithObstacle(at: yOnly) {
            return yOnly
        }
        
        // Jika terkunci total di semua arah, jangan gerakkan karakter
        return player.position
    }
}
