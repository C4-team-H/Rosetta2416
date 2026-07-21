import SpriteKit
import UIKit

final class CockpitMainConsoleNode: SKNode {
    static let artworkScale: CGFloat = 0.8
    static let interactionRadius = GameMapLayout.scaled(76)
    static let outlineWidth = GameMapLayout.scaled(4)

    private static let highlightActionKey = "cockpit-main-console-highlight-transition"
    private static let highlightTransitionDuration: TimeInterval = 0.18

    let artworkSprite: SKSpriteNode
    let artworkSize: CGSize
    private(set) var isProximityHighlighted = false

    private let highlightUniform: SKUniform

    init(
        image: UIImage? = UIImage(named: "CockpitMainConsole"),
        outlineWidth: CGFloat = CockpitMainConsoleNode.outlineWidth
    ) {
        let sourceImage = image ?? UIImage()
        artworkSize = sourceImage.size

        let padding = ceil(outlineWidth) + 2
        let paddedImage = Self.makePaddedImage(sourceImage, padding: padding)
        let paddedTexture = SKTexture(image: paddedImage)
        paddedTexture.filteringMode = .linear
        let paddedDisplaySize = CGSize(
            width: paddedImage.size.width * Self.artworkScale,
            height: paddedImage.size.height * Self.artworkScale
        )

        highlightUniform = SKUniform(name: "u_highlightMix", float: 0)
        let outlineStepUniform = SKUniform(
            name: "u_outlineStep",
            vectorFloat2: SIMD2<Float>(
                Float(outlineWidth / paddedImage.size.width),
                Float(outlineWidth / paddedImage.size.height)
            )
        )

        artworkSprite = SKSpriteNode(texture: paddedTexture, size: paddedDisplaySize)
        artworkSprite.name = "cockpit-main-console-artwork"
        artworkSprite.shader = SKShader(
            source: Self.outlineShaderSource,
            uniforms: [highlightUniform, outlineStepUniform]
        )

        super.init()
        name = "cockpit-main-console"
        addChild(artworkSprite)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setProximityHighlighted(_ isHighlighted: Bool, animated: Bool = true) {
        guard isProximityHighlighted != isHighlighted else { return }
        isProximityHighlighted = isHighlighted
        removeAction(forKey: Self.highlightActionKey)

        let targetValue: Float = isHighlighted ? 1 : 0
        guard animated else {
            highlightUniform.floatValue = targetValue
            return
        }

        let startValue = highlightUniform.floatValue
        let duration = Self.highlightTransitionDuration
        let transition = SKAction.customAction(withDuration: duration) { [weak self] _, elapsedTime in
            let progress = min(max(elapsedTime / duration, 0), 1)
            let easedProgress = progress * progress * (3 - 2 * progress)
            self?.highlightUniform.floatValue = startValue
                + (targetValue - startValue) * Float(easedProgress)
        }
        run(.sequence([
            transition,
            .run { [weak self] in self?.highlightUniform.floatValue = targetValue }
        ]), withKey: Self.highlightActionKey)
    }

    private static func makePaddedImage(_ image: UIImage, padding: CGFloat) -> UIImage {
        let paddedSize = CGSize(
            width: image.size.width + padding * 2,
            height: image.size.height + padding * 2
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: paddedSize, format: format).image { _ in
            image.draw(at: CGPoint(x: padding, y: padding))
        }
    }

    private static let outlineShaderSource: String = {
        let samples = (0..<32).map { index -> String in
            let angle = CGFloat(index) / 32 * .pi * 2
            return String(
                format: "surroundingAlpha = max(surroundingAlpha, texture2D(u_texture, v_tex_coord + vec2(%.8f * u_outlineStep.x, %.8f * u_outlineStep.y)).a);",
                locale: Locale(identifier: "en_US_POSIX"),
                cos(angle),
                sin(angle)
            )
        }.joined(separator: "\n")

        return """
        void main() {
            vec4 baseColor = SKDefaultShading();
            float surroundingAlpha = 0.0;
            \(samples)
            float outlineMask = smoothstep(0.02, 0.30, surroundingAlpha) * (1.0 - baseColor.a);
            float outlineAlpha = outlineMask * u_highlightMix * v_color_mix.a;
            gl_FragColor = baseColor + vec4(vec3(outlineAlpha), outlineAlpha);
        }
        """
    }()
}
