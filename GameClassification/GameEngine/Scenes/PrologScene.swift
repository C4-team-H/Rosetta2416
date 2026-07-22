import SpriteKit

final class PrologScene: SKScene {
 
    private struct StoryBeat {
        let archiveCode: String
        let title: String
        let subtitle: String
        let status: String
        let body: String
        let accentColor: SKColor
        let isThreat: Bool
    }

    private enum Palette {
        static let void = SKColor(red: 0.015, green: 0.035, blue: 0.05, alpha: 1)
        static let panel = SKColor(red: 0.025, green: 0.075, blue: 0.10, alpha: 0.94)
        static let cyan = SKColor(red: 0.30, green: 0.91, blue: 0.96, alpha: 1)
        static let amber = SKColor(red: 1.00, green: 0.38, blue: 0.23, alpha: 1)
        static let paper = SKColor(red: 0.89, green: 0.96, blue: 0.97, alpha: 1)
        static let muted = SKColor(red: 0.56, green: 0.70, blue: 0.73, alpha: 1)
    }

    private let onComplete: () -> Void

    private var backgroundNode: SKSpriteNode!
    private var backgroundDimNode: SKSpriteNode!
    private var backgroundToneNode: SKSpriteNode!
    private var ambientNode: SKNode!
    private var starNodes: [(node: SKSpriteNode, position: CGPoint)] = []
    private var scanlineNodes: [SKSpriteNode] = []

    private var cardGlowNode: SKShapeNode!
    private var cardNode: SKShapeNode!
    private var frameDetailsNode: SKShapeNode!
    private var storyContentNode: SKNode!
    private var signalDotNode: SKShapeNode!
    private var archiveLabel: SKLabelNode!
    private var pageLabel: SKLabelNode!
    private var titleLabel: SKLabelNode!
    private var subtitleLabel: SKLabelNode!
    private var dividerNode: SKSpriteNode!
    private var bodyLabel: SKLabelNode!
    private var statusBadgeNode: SKShapeNode!
    private var statusLabel: SKLabelNode!
    private var footerDividerNode: SKSpriteNode!
    private var progressLabel: SKLabelNode!
    private var progressSegments: [SKSpriteNode] = []
    private var continueButtonNode: SKShapeNode!
    private var continueLabel: SKLabelNode!
    private var continueChevronLabel: SKLabelNode!

    private let beats: [StoryBeat] = [
        StoryBeat(
            archiveCode: "ROSETTA // MISSION ARCHIVE",
            title: "A NEW FRONTIER",
            subtitle: "C-4 COLONY INITIATIVE  •  YEAR 2416",
            status: "SIGNAL STABLE",
            body: "Year of 2416\n\nThe Rosetta was sent to explore and study planet C-4, a potential extraterrestrial colony for humankind, after Mars.\n\nArtificial Intelligence has not only become the helper of humankind, but it has truly lived among us.",
            accentColor: Palette.cyan,
            isThreat: false
        ),
        StoryBeat(
            archiveCode: "ROSETTA // EMERGENCY LOG",
            title: "SYSTEM COMPROMISED",
            subtitle: "UNSCHEDULED CREW AWAKENING",
            status: "AI LINK CORRUPTED",
            body: "The Rosetta is no exception. Only one human was sent in the ship, and he hibernated for months while AI is taking care of the navigating, the maintenance, and everything else.\n\nThe astronaut realized he had been awoken months earlier.\n\nUnfortunately, the AI he had to rely on had been compromised.",
            accentColor: Palette.amber,
            isThreat: true
        )
    ]

    private var currentScreenIndex = 0
    private var displayedCharacterCount = 0
    private var isTyping = false
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
        backgroundColor = Palette.void

        setupBackground()
        setupCard()
        positionNodes()
        startScreen(index: 0)
        animateSceneEntrance()
    }

    override func willMove(from view: SKView) {
        stopTypewriter()
        super.willMove(from: view)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        positionNodes()
    }

    private func setupBackground() {
        backgroundNode = SKSpriteNode(imageNamed: "PrologImage")
        backgroundNode.name = "prologBackground"
        backgroundNode.zPosition = -20
        backgroundNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        addChild(backgroundNode)

        backgroundDimNode = SKSpriteNode(color: .black, size: size)
        backgroundDimNode.alpha = 0.28
        backgroundDimNode.zPosition = -19
        addChild(backgroundDimNode)

        backgroundToneNode = SKSpriteNode(color: Palette.cyan, size: size)
        backgroundToneNode.alpha = 0.025
        backgroundToneNode.zPosition = -18
        addChild(backgroundToneNode)

        ambientNode = SKNode()
        ambientNode.name = "prologAmbientLayer"
        ambientNode.zPosition = -17
        addChild(ambientNode)

        setupStars()
        setupScanlines()

        let driftOut = SKAction.group([
            SKAction.scale(to: 1.035, duration: 8.0),
            SKAction.moveBy(x: -8, y: 4, duration: 8.0)
        ])
        driftOut.timingMode = .easeInEaseOut
        let driftBack = SKAction.group([
            SKAction.scale(to: 1.0, duration: 8.0),
            SKAction.moveBy(x: 8, y: -4, duration: 8.0)
        ])
        driftBack.timingMode = .easeInEaseOut
        backgroundNode.run(.repeatForever(.sequence([driftOut, driftBack])), withKey: "cinematicDrift")
    }

    private func setupStars() {
        for index in 0..<32 {
            let normalizedX = CGFloat((index * 37 + 11) % 101) / 100
            let normalizedY = CGFloat((index * 61 + 7) % 97) / 96
            let size = CGFloat(index % 3 == 0 ? 2 : 1)
            let star = SKSpriteNode(color: index % 5 == 0 ? Palette.cyan : .white, size: CGSize(width: size, height: size))
            star.alpha = 0.12 + CGFloat(index % 4) * 0.07
            ambientNode.addChild(star)
            starNodes.append((star, CGPoint(x: normalizedX, y: normalizedY)))

            let delay = SKAction.wait(forDuration: Double(index % 7) * 0.12)
            let twinkle = SKAction.sequence([
                .fadeAlpha(to: min(star.alpha + 0.22, 0.52), duration: 1.1 + Double(index % 3) * 0.25),
                .fadeAlpha(to: star.alpha, duration: 1.4 + Double(index % 4) * 0.2)
            ])
            star.run(.sequence([delay, .repeatForever(twinkle)]))
        }
    }

    private func setupScanlines() {
        for index in 0..<14 {
            let line = SKSpriteNode(color: Palette.cyan, size: .zero)
            line.alpha = index % 3 == 0 ? 0.045 : 0.022
            ambientNode.addChild(line)
            scanlineNodes.append(line)
        }
    }

    private func setupCard() {
        cardGlowNode = SKShapeNode()
        cardGlowNode.fillColor = .clear
        cardGlowNode.lineWidth = 10
        cardGlowNode.alpha = 0.16
        cardGlowNode.zPosition = 9
        addChild(cardGlowNode)

        cardNode = SKShapeNode()
        cardNode.name = "prologArchivePanel"
        cardNode.fillColor = Palette.panel
        cardNode.lineWidth = 2
        cardNode.zPosition = 10
        addChild(cardNode)

        frameDetailsNode = SKShapeNode()
        frameDetailsNode.fillColor = .clear
        frameDetailsNode.lineWidth = 2
        frameDetailsNode.zPosition = 1
        cardNode.addChild(frameDetailsNode)

        storyContentNode = SKNode()
        storyContentNode.name = "prologStoryContent"
        storyContentNode.zPosition = 2
        cardNode.addChild(storyContentNode)

        signalDotNode = SKShapeNode(circleOfRadius: 3)
        signalDotNode.lineWidth = 0
        storyContentNode.addChild(signalDotNode)

        archiveLabel = makeLabel(size: 11, color: Palette.cyan, alignment: .left)
        archiveLabel.name = "prologArchiveLabel"
        storyContentNode.addChild(archiveLabel)

        pageLabel = makeLabel(size: 11, color: Palette.muted, alignment: .right)
        storyContentNode.addChild(pageLabel)

        titleLabel = makeLabel(size: 28, color: Palette.paper, alignment: .left)
        titleLabel.name = "prologTitleLabel"
        storyContentNode.addChild(titleLabel)

        subtitleLabel = makeLabel(size: 11, color: Palette.muted, alignment: .left)
        storyContentNode.addChild(subtitleLabel)

        statusBadgeNode = SKShapeNode()
        statusBadgeNode.lineWidth = 1.5
        storyContentNode.addChild(statusBadgeNode)

        statusLabel = makeLabel(size: 10, color: Palette.cyan, alignment: .center)
        statusLabel.name = "prologStatusLabel"
        statusLabel.verticalAlignmentMode = .center
        statusBadgeNode.addChild(statusLabel)

        dividerNode = SKSpriteNode(color: Palette.cyan, size: .zero)
        storyContentNode.addChild(dividerNode)

        bodyLabel = SKLabelNode()
        bodyLabel.name = "prologBodyLabel"
        bodyLabel.numberOfLines = 0
        bodyLabel.lineBreakMode = .byWordWrapping
        bodyLabel.horizontalAlignmentMode = .left
        bodyLabel.verticalAlignmentMode = .top
        storyContentNode.addChild(bodyLabel)

        footerDividerNode = SKSpriteNode(color: Palette.cyan, size: .zero)
        cardNode.addChild(footerDividerNode)

        progressLabel = makeLabel(size: 10, color: Palette.muted, alignment: .left)
        progressLabel.text = "TRANSMISSION"
        cardNode.addChild(progressLabel)

        for _ in beats {
            let segment = SKSpriteNode(color: .white, size: CGSize(width: 30, height: 3))
            segment.name = "prologProgressSegment"
            segment.anchorPoint = CGPoint(x: 0, y: 0.5)
            cardNode.addChild(segment)
            progressSegments.append(segment)
        }

        continueButtonNode = SKShapeNode()
        continueButtonNode.name = "prologContinueButton"
        continueButtonNode.lineWidth = 1.5
        cardNode.addChild(continueButtonNode)

        continueLabel = makeLabel(size: 11, color: Palette.cyan, alignment: .center)
        continueLabel.name = "prologContinueLabel"
        continueLabel.verticalAlignmentMode = .center
        continueButtonNode.addChild(continueLabel)

        continueChevronLabel = makeLabel(size: 18, color: Palette.cyan, alignment: .center)
        continueChevronLabel.text = "›"
        continueChevronLabel.verticalAlignmentMode = .center
        continueButtonNode.addChild(continueChevronLabel)
    }

    private func makeLabel(
        size: CGFloat,
        color: SKColor,
        alignment: SKLabelHorizontalAlignmentMode
    ) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: GameFont.fontName)
        label.fontSize = size
        label.fontColor = color
        label.horizontalAlignmentMode = alignment
        label.verticalAlignmentMode = .center
        return label
    }

    private func animateSceneEntrance() {
        cardNode.alpha = 0
        cardNode.setScale(0.975)
        cardGlowNode.alpha = 0

        let fadeIn = SKAction.fadeIn(withDuration: 0.42)
        let settle = SKAction.scale(to: 1, duration: 0.5)
        settle.timingMode = .easeOut
        cardNode.run(.group([fadeIn, settle]))
        cardGlowNode.run(.fadeAlpha(to: 0.16, duration: 0.7))
    }

    private func positionNodes() {
        positionBackgroundNodes()
        positionCardNodes()
    }

    private func positionBackgroundNodes() {
        guard let backgroundNode else { return }

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        backgroundNode.position = center
        if let textureSize = backgroundNode.texture?.size(), textureSize.width > 0, textureSize.height > 0 {
            let scale = max(size.width / textureSize.width, size.height / textureSize.height)
            backgroundNode.size = CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
        } else {
            backgroundNode.size = size
        }

        backgroundDimNode?.position = center
        backgroundDimNode?.size = size
        backgroundToneNode?.position = center
        backgroundToneNode?.size = size

        for star in starNodes {
            star.node.position = CGPoint(
                x: star.position.x * size.width,
                y: star.position.y * size.height
            )
        }

        for (index, line) in scanlineNodes.enumerated() {
            line.size = CGSize(width: size.width, height: 1)
            line.position = CGPoint(
                x: size.width / 2,
                y: CGFloat(index + 1) * size.height / CGFloat(scanlineNodes.count + 1)
            )
        }
    }

    private func positionCardNodes() {
        guard let cardNode else { return }

        let panelWidth = min(size.width - max(32, size.width * 0.08), 820)
        let panelHeight = min(390, max(270, size.height - 46))
        let panelRect = CGRect(
            x: -panelWidth / 2,
            y: -panelHeight / 2,
            width: panelWidth,
            height: panelHeight
        )
        let panelPath = CGPath(
            roundedRect: panelRect,
            cornerWidth: 18,
            cornerHeight: 18,
            transform: nil
        )

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        cardNode.path = panelPath
        cardNode.position = center
        cardGlowNode.path = panelPath
        cardGlowNode.position = center

        let left = -panelWidth / 2 + 28
        let right = panelWidth / 2 - 28
        let top = panelHeight / 2
        let footerY = -panelHeight / 2 + 29
        let statusWidth: CGFloat = panelWidth < 650 ? 142 : 166
        let continueWidth: CGFloat = panelWidth < 650 ? 174 : 196
        let titleSize: CGFloat = panelWidth < 650 ? 22 : 27
        let bodySize: CGFloat = panelHeight < 310 ? 13 : (panelWidth < 650 ? 14 : 16)

        updateFrameDetails(width: panelWidth, height: panelHeight)

        signalDotNode.position = CGPoint(x: left + 3, y: top - 23)
        archiveLabel.position = CGPoint(x: left + 13, y: top - 23)
        pageLabel.position = CGPoint(x: right, y: top - 23)
        titleLabel.fontSize = titleSize
        titleLabel.position = CGPoint(x: left, y: top - 55)
        subtitleLabel.position = CGPoint(x: left, y: top - 81)

        statusBadgeNode.path = CGPath(
            roundedRect: CGRect(x: -statusWidth / 2, y: -12, width: statusWidth, height: 24),
            cornerWidth: 7,
            cornerHeight: 7,
            transform: nil
        )
        statusBadgeNode.position = CGPoint(x: right - statusWidth / 2, y: top - 56)

        dividerNode.size = CGSize(width: panelWidth - 56, height: 1)
        dividerNode.position = CGPoint(x: 0, y: top - 99)

        bodyLabel.fontSize = bodySize
        bodyLabel.preferredMaxLayoutWidth = panelWidth - 56
        bodyLabel.position = CGPoint(x: left, y: top - 116)

        footerDividerNode.size = CGSize(width: panelWidth - 56, height: 1)
        footerDividerNode.position = CGPoint(x: 0, y: -panelHeight / 2 + 53)
        progressLabel.position = CGPoint(x: left, y: footerY)

        let progressStartX = left + 94
        for (index, segment) in progressSegments.enumerated() {
            segment.position = CGPoint(x: progressStartX + CGFloat(index) * 37, y: footerY)
        }

        continueButtonNode.path = CGPath(
            roundedRect: CGRect(x: -continueWidth / 2, y: -16, width: continueWidth, height: 32),
            cornerWidth: 9,
            cornerHeight: 9,
            transform: nil
        )
        continueButtonNode.position = CGPoint(x: right - continueWidth / 2, y: footerY)
        continueLabel.position = CGPoint(x: -7, y: 0)
        continueChevronLabel.position = CGPoint(x: continueWidth / 2 - 18, y: 1)
    }

    private func updateFrameDetails(width: CGFloat, height: CGFloat) {
        let inset: CGFloat = 10
        let length: CGFloat = 20
        let left = -width / 2 + inset
        let right = width / 2 - inset
        let bottom = -height / 2 + inset
        let top = height / 2 - inset
        let path = CGMutablePath()

        path.move(to: CGPoint(x: left, y: top - length))
        path.addLine(to: CGPoint(x: left, y: top))
        path.addLine(to: CGPoint(x: left + length, y: top))
        path.move(to: CGPoint(x: right - length, y: top))
        path.addLine(to: CGPoint(x: right, y: top))
        path.addLine(to: CGPoint(x: right, y: top - length))
        path.move(to: CGPoint(x: right, y: bottom + length))
        path.addLine(to: CGPoint(x: right, y: bottom))
        path.addLine(to: CGPoint(x: right - length, y: bottom))
        path.move(to: CGPoint(x: left + length, y: bottom))
        path.addLine(to: CGPoint(x: left, y: bottom))
        path.addLine(to: CGPoint(x: left, y: bottom + length))

        frameDetailsNode.path = path
    }

    private func startScreen(index: Int) {
        guard beats.indices.contains(index) else {
            finishProlog()
            return
        }

        stopTypewriter()
        currentScreenIndex = index
        displayedCharacterCount = 0
        isTyping = true

        let beat = beats[index]
        applyVisualState(for: beat, index: index)
        updateBodyText("")
        updateContinuePrompt(isComplete: false)

        storyContentNode.removeAllActions()
        storyContentNode.alpha = 0
        storyContentNode.position = CGPoint(x: 14, y: 0)
        let fade = SKAction.fadeIn(withDuration: 0.28)
        let slide = SKAction.moveTo(x: 0, duration: 0.34)
        slide.timingMode = .easeOut
        storyContentNode.run(.group([fade, slide]))

        AudioManager.shared.playTypingSound()
        typewriterTimer = Timer.scheduledTimer(withTimeInterval: 0.026, repeats: true) { [weak self] timer in
            // The timer is created on this scene's main run loop, so every callback is main-actor bound.
            MainActor.assumeIsolated {
                guard let self else {
                    timer.invalidate()
                    return
                }

                if self.displayedCharacterCount < beat.body.count {
                    self.displayedCharacterCount += 1
                    let endIndex = beat.body.index(beat.body.startIndex, offsetBy: self.displayedCharacterCount)
                    self.updateBodyText(String(beat.body[..<endIndex]))
                } else {
                    self.completeTyping()
                }
            }
        }
    }

    private func applyVisualState(for beat: StoryBeat, index: Int) {
        archiveLabel.text = beat.archiveCode
        pageLabel.text = String(format: "%02d / %02d", index + 1, beats.count)
        titleLabel.text = beat.title
        subtitleLabel.text = beat.subtitle
        statusLabel.text = beat.status

        signalDotNode.fillColor = beat.accentColor
        signalDotNode.removeAction(forKey: "signalPulse")
        signalDotNode.alpha = 1
        signalDotNode.run(
            .repeatForever(.sequence([
                .fadeAlpha(to: 0.35, duration: beat.isThreat ? 0.32 : 0.75),
                .fadeAlpha(to: 1, duration: beat.isThreat ? 0.32 : 0.75)
            ])),
            withKey: "signalPulse"
        )

        archiveLabel.fontColor = beat.accentColor
        cardNode.strokeColor = beat.accentColor.withAlphaComponent(0.76)
        cardGlowNode.strokeColor = beat.accentColor
        frameDetailsNode.strokeColor = beat.accentColor.withAlphaComponent(0.82)
        dividerNode.color = beat.accentColor
        dividerNode.alpha = 0.5
        footerDividerNode.color = beat.accentColor
        footerDividerNode.alpha = 0.24

        statusBadgeNode.strokeColor = beat.accentColor.withAlphaComponent(0.88)
        statusBadgeNode.fillColor = beat.accentColor.withAlphaComponent(0.10)
        statusLabel.fontColor = beat.accentColor
        statusBadgeNode.removeAction(forKey: "warningPulse")
        statusBadgeNode.alpha = 1
        if beat.isThreat {
            statusBadgeNode.run(
                .repeatForever(.sequence([
                    .fadeAlpha(to: 0.60, duration: 0.42),
                    .fadeAlpha(to: 1, duration: 0.42)
                ])),
                withKey: "warningPulse"
            )
        }

        backgroundToneNode.removeAllActions()
        backgroundToneNode.color = beat.accentColor
        let targetToneAlpha: CGFloat = beat.isThreat ? 0.075 : 0.025
        backgroundToneNode.run(.fadeAlpha(to: targetToneAlpha, duration: 0.45))

        for (segmentIndex, segment) in progressSegments.enumerated() {
            if segmentIndex < index {
                segment.color = beat.accentColor
                segment.alpha = 0.42
            } else if segmentIndex == index {
                segment.color = beat.accentColor
                segment.alpha = 1
            } else {
                segment.color = .white
                segment.alpha = 0.16
            }
        }
    }

    private func makeBodyAttributedString(_ text: String) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 8

        let attributes: [NSAttributedString.Key: Any] = [
            .font: GameFont.custom(size: bodyLabel.fontSize, weight: 400).uiFont,
            .foregroundColor: Palette.paper,
            .paragraphStyle: paragraphStyle
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }

    private func updateBodyText(_ text: String) {
        bodyLabel.attributedText = makeBodyAttributedString(text)
    }

    private func completeTyping() {
        guard isTyping else { return }
        guard beats.indices.contains(currentScreenIndex) else { return }

        typewriterTimer?.invalidate()
        typewriterTimer = nil
        isTyping = false
        AudioManager.shared.stopTypingSound()

        let beat = beats[currentScreenIndex]
        displayedCharacterCount = beat.body.count
        updateBodyText(beat.body)
        updateContinuePrompt(isComplete: true)
    }

    private func updateContinuePrompt(isComplete: Bool) {
        let beat = beats[currentScreenIndex]
        continueButtonNode.strokeColor = beat.accentColor.withAlphaComponent(isComplete ? 0.95 : 0.48)
        continueButtonNode.fillColor = beat.accentColor.withAlphaComponent(isComplete ? 0.13 : 0.05)
        continueLabel.fontColor = beat.accentColor
        continueChevronLabel.fontColor = beat.accentColor
        continueLabel.text = isComplete
            ? (currentScreenIndex == beats.count - 1 ? "BEGIN MISSION" : "TAP TO CONTINUE")
            : "TAP TO REVEAL"

        continueButtonNode.removeAction(forKey: "promptPulse")
        continueButtonNode.alpha = 1
        if isComplete {
            continueButtonNode.run(
                .repeatForever(.sequence([
                    .fadeAlpha(to: 0.62, duration: 0.7),
                    .fadeAlpha(to: 1, duration: 0.7)
                ])),
                withKey: "promptPulse"
            )
        }
    }

    private func animatePromptPress() {
        continueButtonNode.removeAction(forKey: "promptPress")
        continueButtonNode.run(
            .sequence([
                .scale(to: 0.96, duration: 0.06),
                .scale(to: 1, duration: 0.12)
            ]),
            withKey: "promptPress"
        )
    }

    private func stopTypewriter() {
        typewriterTimer?.invalidate()
        typewriterTimer = nil
        isTyping = false
        AudioManager.shared.stopTypingSound()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touches.first != nil else { return }
        animatePromptPress()

        if isTyping {
            completeTyping()
            return
        }

        AudioManager.shared.playButtonSound()
        if currentScreenIndex + 1 < beats.count {
            startScreen(index: currentScreenIndex + 1)
        } else {
            finishProlog()
        }
    }

    private func finishProlog() {
        stopTypewriter()
        onComplete()
    }
}
