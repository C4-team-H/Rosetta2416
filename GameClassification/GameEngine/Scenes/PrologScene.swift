import SpriteKit

final class PrologScene: SKScene {

    private let onComplete: () -> Void

    private var backgroundNode: SKSpriteNode!
    private var cardNode: SKShapeNode!
    private var paragraphLabels: [SKLabelNode] = []
    private var continueLabel: SKLabelNode!

    private let screens: [String] = [
        "Year of 2416\n\nThe Rosetta was sent to explore and study planet C-4, a potential extraterrestrial colony for humankind, after Mars.\n\nArtificial Intelligence has not only become the helper of humankind, but it has truly lived among us.",
        "The Rosetta is no exception. Only one human was sent in the ship, and he hibernated for months while AI is taking care of the navigating, the maintenance, and everything else.\n\nThe astronaut realized he had been awoken months earlier.\n\nUnfortunately, the AI he had to rely on had been compromised."
    ]

    private var currentScreenIndex: Int = 0
    private var displayedCharacterCount: Int = 0
    private var isTyping: Bool = false
    private var typewriterTimer: Timer?

    init(size: CGSize, onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        AudioManager.shared.playMainMenuMusic()
        backgroundColor = .black

        setupBackground()
        setupCard()
        startScreen(index: 0)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        positionNodes()
    }

    private func setupBackground() {
        backgroundNode = SKSpriteNode(imageNamed: "PrologImage")
        backgroundNode.name = "prologBackground"
        backgroundNode.zPosition = -10
        backgroundNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        addChild(backgroundNode)
        positionBackgroundNode()
    }

    private func setupCard() {
        let cardWidth = min(size.width * 0.85, 640)
        let cardHeight: CGFloat = 300
        cardNode = SKShapeNode(rectOf: CGSize(width: cardWidth, height: cardHeight), cornerRadius: 16)
        cardNode.fillColor = SKColor.black.withAlphaComponent(0.72)
        cardNode.strokeColor = SKColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 0.6)
        cardNode.lineWidth = 2
        cardNode.zPosition = 10
        addChild(cardNode)

        continueLabel = SKLabelNode(fontNamed: GameFont.fontName)
        continueLabel.text = "TAP TO CONTINUE"
        continueLabel.fontSize = 14
        continueLabel.fontColor = SKColor(red: 0.35, green: 0.85, blue: 1.0, alpha: 1.0)
        continueLabel.horizontalAlignmentMode = .center
        continueLabel.verticalAlignmentMode = .bottom
        continueLabel.zPosition = 11
        continueLabel.isHidden = true

        let pulseAction = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: 0.6),
                SKAction.fadeAlpha(to: 1.0, duration: 0.6)
            ])
        )
        continueLabel.run(pulseAction)
        cardNode.addChild(continueLabel)

        positionCardNodes()
    }

    private func positionNodes() {
        positionBackgroundNode()
        positionCardNodes()
    }

    private func positionBackgroundNode() {
        guard let backgroundNode else { return }
        backgroundNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        guard let textureSize = backgroundNode.texture?.size(), textureSize.width > 0, textureSize.height > 0 else {
            backgroundNode.size = size
            return
        }
        let scale = max(size.width / textureSize.width, size.height / textureSize.height)
        backgroundNode.size = CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
    }

    private func positionCardNodes() {
        guard let cardNode else { return }
        let cardWidth = min(size.width * 0.85, 640)
        let cardHeight: CGFloat = 300

        cardNode.path = CGPath(
            roundedRect: CGRect(x: -cardWidth / 2, y: -cardHeight / 2, width: cardWidth, height: cardHeight),
            cornerWidth: 16,
            cornerHeight: 16,
            transform: nil
        )
        cardNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        continueLabel?.position = CGPoint(x: 0, y: -cardHeight / 2 + 18)
    }

    private func startScreen(index: Int) {
        guard index >= 0 && index < screens.count else {
            finishProlog()
            return
        }

        currentScreenIndex = index
        displayedCharacterCount = 0
        isTyping = true
        continueLabel.isHidden = true

        for label in paragraphLabels {
            label.removeFromParent()
        }
        paragraphLabels.removeAll()

        let fullText = screens[index]
        let paragraphTexts = fullText.components(separatedBy: "\n\n")

        let cardWidth = min(size.width * 0.85, 640)
        let cardHeight: CGFloat = 300
        let maxTextWidth = cardWidth - 48

        var currentY = cardHeight / 2 - 28

        for pText in paragraphTexts {
            let label = SKLabelNode()
            label.numberOfLines = 0
            label.lineBreakMode = .byWordWrapping
            label.preferredMaxLayoutWidth = maxTextWidth
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .top
            label.position = CGPoint(x: 0, y: currentY)
            label.zPosition = 11
            label.attributedText = makeCenteredAttributedString("")

            cardNode.addChild(label)
            paragraphLabels.append(label)

            let estimatedLines = max(1, ceil(CGFloat(pText.count) / 52.0))
            let paragraphHeight = estimatedLines * 22.0
            currentY -= (paragraphHeight + 16.0)
        }

        typewriterTimer?.invalidate()
        AudioManager.shared.playTypingSound()

        typewriterTimer = Timer.scheduledTimer(withTimeInterval: 0.035, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            if self.displayedCharacterCount < fullText.count {
                self.displayedCharacterCount += 1
                self.updateTypedParagraphs(fullText: fullText, paragraphTexts: paragraphTexts)
            } else {
                timer.invalidate()
                self.typewriterTimer = nil
                self.isTyping = false
                self.updateTypedParagraphs(fullText: fullText, paragraphTexts: paragraphTexts)
                self.continueLabel.isHidden = false
                AudioManager.shared.stopTypingSound()
            }
        }
    }

    private func makeCenteredAttributedString(_ text: String) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 4

        let attributes: [NSAttributedString.Key: Any] = [
            .font: GameFont.custom(size: 17, weight: 400).uiFont,
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }

    private func updateTypedParagraphs(fullText: String, paragraphTexts: [String]) {
        var remainingChars = displayedCharacterCount

        for (i, pText) in paragraphTexts.enumerated() {
            guard i < paragraphLabels.count else { break }
            let label = paragraphLabels[i]

            if remainingChars <= 0 {
                label.attributedText = makeCenteredAttributedString("")
            } else if remainingChars < pText.count {
                let endIdx = pText.index(pText.startIndex, offsetBy: remainingChars)
                label.attributedText = makeCenteredAttributedString(String(pText[..<endIdx]))
                remainingChars = 0
            } else {
                label.attributedText = makeCenteredAttributedString(pText)
                remainingChars -= pText.count
                remainingChars -= 2
            }
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touches.first != nil else { return }

        if isTyping {
            return
        }

        AudioManager.shared.playButtonSound()
        if currentScreenIndex + 1 < screens.count {
            startScreen(index: currentScreenIndex + 1)
        } else {
            finishProlog()
        }
    }

    private func finishProlog() {
        typewriterTimer?.invalidate()
        typewriterTimer = nil
        AudioManager.shared.stopTypingSound()
        onComplete()
    }
}
