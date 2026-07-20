import SpriteKit
import UIKit

final class RocketPowerOffSmokeNode: SKNode {
    static let frameNames = [
        "RocketPowerOffSmoke1",
        "RocketPowerOffSmoke2",
        "RocketPowerOffSmoke3",
        "RocketPowerOffSmoke4"
    ]
    static let displayScale: CGFloat = 1.6
    static let frameDuration: TimeInterval = 0.14

    static let animationActionKey = "rocket-power-off-smoke-animation"

    let artworkSprite: SKSpriteNode
    let artworkSize: CGSize
    let animationFrameCount: Int

    private let textures: [SKTexture]
    private(set) var isEffectActive = false

    init(images: [UIImage]? = nil) {
        let loadedImages = images ?? Self.loadFrameImages()
        let sourceImages = loadedImages.isEmpty ? [Self.makeFallbackImage()] : loadedImages
        artworkSize = sourceImages[0].size
        animationFrameCount = sourceImages.count
        textures = sourceImages.map { image in
            let texture = SKTexture(image: image)
            texture.filteringMode = .linear
            return texture
        }

        artworkSprite = SKSpriteNode(
            texture: textures[0],
            size: CGSize(
                width: artworkSize.width * Self.displayScale,
                height: artworkSize.height * Self.displayScale
            )
        )
        artworkSprite.name = "rocket-power-off-smoke-artwork"
        artworkSprite.xScale = 1
        artworkSprite.yScale = 1

        super.init()
        name = "rocket-power-off-smoke"
        isHidden = true
        addChild(artworkSprite)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setEffectActive(_ isActive: Bool) {
        guard isEffectActive != isActive else { return }
        isEffectActive = isActive
        isHidden = !isActive

        if isActive {
            startAnimation()
        } else {
            artworkSprite.removeAction(forKey: Self.animationActionKey)
            artworkSprite.texture = textures[0]
        }
    }

    private func startAnimation() {
        guard artworkSprite.action(forKey: Self.animationActionKey) == nil else { return }
        artworkSprite.run(
            .repeatForever(.animate(
                with: textures,
                timePerFrame: Self.frameDuration,
                resize: false,
                restore: false
            )),
            withKey: Self.animationActionKey
        )
    }

    private static func loadFrameImages() -> [UIImage] {
        frameNames.compactMap { UIImage(named: $0) }
    }

    private static func makeFallbackImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1), format: format).image { _ in }
    }
}
