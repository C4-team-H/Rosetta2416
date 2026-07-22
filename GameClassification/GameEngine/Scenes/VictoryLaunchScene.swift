import SpriteKit

final class VictoryLaunchScene: SKScene {
    static let backgroundNodeName = "victoryLaunchBackground"
    static let shipAssemblyNodeName = "victoryLaunchShipAssembly"
    static let shipNodeName = "rosettaShip"
    static let jetFireNodeName = "jetFire"
    static let jetFireAnimationKey = "jetFireAnimation"
    static let launchAnimationKey = "victoryLaunchAnimation"

    private enum AssetName {
        static let background = "VictoryLaunchBackground"
        static let ship = "RosettaShip"
        static let jetFireFrames = (1...4).map { "JetFire\($0)" }
    }

    /// Normalized alpha bounds of the supplied 2752 x 2064 artwork. Cropping at
    /// the texture level keeps the original files untouched while making layout
    /// calculations use only the visible ship and flame pixels.
    private enum ArtworkCrop {
        static let ship = CGRect(
            x: 238.0 / 2752.0,
            y: 0,
            width: 2276.0 / 2752.0,
            height: 1519.0 / 2064.0
        )
        static let jetFire = CGRect(
            x: 1065.0 / 2752.0,
            y: 469.0 / 2064.0,
            width: 625.0 / 2752.0,
            height: 754.0 / 2064.0
        )
    }

    private let onCompletion: () -> Void
    private let backgroundNode = SKSpriteNode(texture: SKTexture(imageNamed: AssetName.background))
    private let shipAssembly = SKNode()
    private let shipNode = SKSpriteNode(
        texture: VictoryLaunchScene.croppedTexture(named: AssetName.ship, rect: ArtworkCrop.ship)
    )
    private let jetFireTextures = AssetName.jetFireFrames.map {
        VictoryLaunchScene.croppedTexture(named: $0, rect: ArtworkCrop.jetFire)
    }
    private lazy var jetFireNode = SKSpriteNode(texture: jetFireTextures.first)
    private var didBuildScene = false
    private var didCompleteCutscene = false

    init(size: CGSize, onCompletion: @escaping () -> Void) {
        self.onCompletion = onCompletion
        super.init(size: size)
        backgroundColor = .black
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        guard !didBuildScene else { return }
        didBuildScene = true
        buildScene()
        startLaunchAnimation()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard didBuildScene else { return }
        layoutBackground()
    }

    private func buildScene() {
        backgroundNode.name = Self.backgroundNodeName
        backgroundNode.zPosition = -10
        addChild(backgroundNode)

        shipAssembly.name = Self.shipAssemblyNodeName
        shipAssembly.zPosition = 1
        addChild(shipAssembly)

        shipNode.name = Self.shipNodeName
        shipNode.zPosition = 1
        shipAssembly.addChild(shipNode)

        jetFireNode.name = Self.jetFireNodeName
        jetFireNode.anchorPoint = CGPoint(x: 0.5, y: 1)
        jetFireNode.zPosition = 0
        shipAssembly.addChild(jetFireNode)

        layoutBackground()
        layoutShipAssembly()
        animateJetFire()
    }

    private func layoutBackground() {
        guard let texture = backgroundNode.texture else { return }
        let textureSize = texture.size()
        guard textureSize.width > 0, textureSize.height > 0 else { return }

        let fillScale = max(size.width / textureSize.width, size.height / textureSize.height)
        backgroundNode.size = CGSize(
            width: textureSize.width * fillScale,
            height: textureSize.height * fillScale
        )
        backgroundNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    private func layoutShipAssembly() {
        guard let shipTexture = shipNode.texture,
              let fireTexture = jetFireNode.texture else { return }

        let shipTextureSize = shipTexture.size()
        let shipAspectRatio = shipTextureSize.width / shipTextureSize.height
        let shipWidth = min(size.width * 0.78, size.height * 0.62 * shipAspectRatio)
        let shipHeight = shipWidth / shipAspectRatio
        shipNode.size = CGSize(width: shipWidth, height: shipHeight)

        let fireTextureSize = fireTexture.size()
        let fireAspectRatio = fireTextureSize.width / fireTextureSize.height
        let fireWidth = shipWidth * 0.28
        let fireHeight = fireWidth / fireAspectRatio
        jetFireNode.size = CGSize(width: fireWidth, height: fireHeight)
        jetFireNode.position = CGPoint(x: 0, y: -shipHeight / 2 + shipHeight * 0.025)

        shipAssembly.position = CGPoint(
            x: size.width / 2,
            y: -shipHeight / 2 - fireHeight - 16
        )
    }

    private func animateJetFire() {
        guard !jetFireTextures.isEmpty else { return }
        let frames = SKAction.animate(
            with: jetFireTextures,
            timePerFrame: 0.085,
            resize: false,
            restore: false
        )
        jetFireNode.run(.repeatForever(frames), withKey: Self.jetFireAnimationKey)
    }

    private func startLaunchAnimation() {
        let shipHeight = shipNode.size.height
        let fireHeight = jetFireNode.size.height
        let targetY = size.height + shipHeight / 2 + fireHeight + 20
        let launch = SKAction.moveTo(y: targetY, duration: 4.2)
        launch.timingMode = .easeIn

        shipAssembly.run(.sequence([
            .wait(forDuration: 0.35),
            launch,
            .run { [weak self] in self?.finishCutscene() }
        ]), withKey: Self.launchAnimationKey)
    }

    private func finishCutscene() {
        guard !didCompleteCutscene else { return }
        didCompleteCutscene = true

        let fadeOverlay = SKSpriteNode(color: .black, size: size)
        fadeOverlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        fadeOverlay.zPosition = 20
        fadeOverlay.alpha = 0
        addChild(fadeOverlay)
        fadeOverlay.run(.sequence([
            .fadeIn(withDuration: 0.55),
            .run { [weak self] in self?.onCompletion() }
        ]))
    }

    private static func croppedTexture(named name: String, rect: CGRect) -> SKTexture {
        let source = SKTexture(imageNamed: name)
        source.filteringMode = .linear
        let cropped = SKTexture(rect: rect, in: source)
        cropped.filteringMode = .linear
        return cropped
    }
}
