//
//  MainMenuScene.swift
//  GameClassification
//
//  Created by Muhammad Muthi' Nuritzan on 13/07/26.
//

import SpriteKit

final class MainMenuScene: SKScene {

    private var titleLabel: SKLabelNode!
    private var backgroundNode: SKSpriteNode!
    private let starFieldNode = SKNode()
    private var startButton: SKSpriteNode?
    private var newGameButton: SKSpriteNode!
    private weak var pressedButton: SKSpriteNode?
    private var isPressedFeedbackActive = false
    private var isActivatingButton = false
    private let coordinator: GameplayCoordinator

    private static let buttonPressAnimationKey = "mainMenuButtonPressAnimation"
    private static let pressedButtonScale: CGFloat = 0.96
    private static let pressedButtonShade: CGFloat = 0.18
    private static let starSizeMultipliers: [CGFloat] = [0.65, 1.0, 1.45, 1.9]

    init(size: CGSize, coordinator: GameplayCoordinator) {
        self.coordinator = coordinator
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMove(to view: SKView) {
        AudioManager.shared.playMainMenuMusic()
        backgroundColor = SKColor(red: 0.1, green: 0.12, blue: 0.18, alpha: 1.0)

        backgroundNode = SKSpriteNode(imageNamed: "MainMenuBackground")
        backgroundNode.name = "mainMenuBackground"
        backgroundNode.zPosition = -10
        backgroundNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        addChild(backgroundNode)

        setupStarField()
        
        if coordinator.hasSavedProgress {
            let continueButton = makeImageButton(name: "startButton", imageName: "ContinueButton")
            startButton = continueButton
            addChild(continueButton)
        }
        newGameButton = makeImageButton(name: "newGameButton", imageName: "NewGameButton")
        self.addChild(newGameButton)

        updateMenuButtons()
    }
    
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        
        // Recalculate button sizes based on 1/4 screen width
        let targetWidth = size.width / 4
        let targetHeight = targetWidth * (332.0 / 1390.0)
        let buttonSize = CGSize(width: targetWidth, height: targetHeight)
        startButton?.size = buttonSize
        newGameButton?.size = buttonSize
        
        positionMenuNodes()
        rebuildStarField()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isActivatingButton,
              pressedButton == nil,
              let touch = touches.first,
              let button = button(at: touch.location(in: self)) else { return }

        pressedButton = button
        setPressed(true, for: button)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let button = pressedButton, let touch = touches.first else { return }
        setPressed(buttonHitFrame(button).contains(touch.location(in: self)), for: button)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let button = pressedButton else { return }
        pressedButton = nil

        let shouldActivate = touches.first.map {
            buttonHitFrame(button).contains($0.location(in: self))
        } ?? false

        release(button, activating: shouldActivate)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let button = pressedButton else { return }
        pressedButton = nil
        release(button, activating: false)
    }

    private func button(at location: CGPoint) -> SKSpriteNode? {
        return nodes(at: location).compactMap { $0 as? SKSpriteNode }.first {
            $0.name == "startButton" || $0.name == "newGameButton"
        }
    }

    private func buttonHitFrame(_ button: SKSpriteNode) -> CGRect {
        CGRect(
            x: button.position.x - button.size.width * button.anchorPoint.x,
            y: button.position.y - button.size.height * button.anchorPoint.y,
            width: button.size.width,
            height: button.size.height
        )
    }

    private func setPressed(_ isPressed: Bool, for button: SKSpriteNode) {
        guard isPressedFeedbackActive != isPressed else { return }
        isPressedFeedbackActive = isPressed
        button.removeAction(forKey: Self.buttonPressAnimationKey)

        let scale = SKAction.scale(to: isPressed ? Self.pressedButtonScale : 1, duration: 0.08)
        let shade = SKAction.colorize(
            withColorBlendFactor: isPressed ? Self.pressedButtonShade : 0,
            duration: 0.08
        )
        let feedback = SKAction.group([scale, shade])
        feedback.timingMode = .easeOut
        button.run(feedback, withKey: Self.buttonPressAnimationKey)
    }

    private func release(_ button: SKSpriteNode, activating shouldActivate: Bool) {
        guard shouldActivate else {
            setPressed(false, for: button)
            return
        }

        isPressedFeedbackActive = false
        isActivatingButton = true
        button.removeAction(forKey: Self.buttonPressAnimationKey)

        let rebound = SKAction.group([
            SKAction.scale(to: 1.015, duration: 0.07),
            SKAction.colorize(withColorBlendFactor: 0, duration: 0.07)
        ])
        rebound.timingMode = .easeOut

        let settle = SKAction.scale(to: 1, duration: 0.05)
        settle.timingMode = .easeInEaseOut

        button.run(.sequence([
            rebound,
            settle,
            .run { [weak self, weak button] in
                guard let self, let button else { return }
                self.activate(button)
            }
        ]), withKey: Self.buttonPressAnimationKey)
    }

    private func activate(_ button: SKSpriteNode) {
        switch button.name {
        case "startButton":
            startGame()
        case "newGameButton":
            startNewGame()
        default:
            isActivatingButton = false
        }
    }

    private func startGame() {
        AudioManager.shared.playButtonSound()
        guard let view else {
            isActivatingButton = false
            return
        }
        coordinator.continueGame(in: view, size: size)
    }

    private func startNewGame() {
        AudioManager.shared.playButtonSound()
        guard let view else {
            isActivatingButton = false
            return
        }
        coordinator.startNewGame(in: view, size: size)
    }

    private func makeImageButton(name: String, imageName: String) -> SKSpriteNode {
        let button = SKSpriteNode(imageNamed: imageName)
        button.name = name
        button.color = .black
        button.colorBlendFactor = 0
        let targetWidth = size.width / 4
        let targetHeight = targetWidth * (332.0 / 1390.0)
        button.size = CGSize(width: targetWidth, height: targetHeight)
        return button
    }

    func updateMenuButtons() {
        let hasSave = coordinator.hasSavedProgress
        if hasSave {
            if startButton == nil {
                startButton = makeImageButton(name: "startButton", imageName: "ContinueButton")
            }
            if let startButton, startButton.parent == nil {
                addChild(startButton)
            }
        } else {
            startButton?.removeFromParent()
        }
        positionMenuNodes()
    }

    private func positionMenuNodes() {
        positionBackgroundNode()
        titleLabel?.position = CGPoint(x: size.width / 2, y: size.height * 0.68)
        let hasSave = coordinator.hasSavedProgress
        if hasSave {
            startButton?.position = CGPoint(x: size.width / 2, y: size.height * 0.24)
            newGameButton?.position = CGPoint(x: size.width / 2, y: size.height * 0.14)
        } else {
            newGameButton?.position = CGPoint(x: size.width / 2, y: size.height * 0.24)
        }
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

    private func setupStarField() {
        starFieldNode.name = "mainMenuStarField"
        starFieldNode.zPosition = -5
        starFieldNode.isUserInteractionEnabled = false
        if starFieldNode.parent == nil {
            addChild(starFieldNode)
        }
        rebuildStarField()
    }

    private func rebuildStarField() {
        guard starFieldNode.parent != nil, size.width > 0, size.height > 0 else { return }

        starFieldNode.removeAllChildren()

        let texture = SKTexture(imageNamed: "BlinkStar")
        texture.filteringMode = .linear
        let textureSize = texture.size()
        let aspectRatio = textureSize.height / max(textureSize.width, 1)
        let sceneArea = size.width * size.height
        let starCount = max(18, min(34, Int(sceneArea / 28_000)))
        let baseWidth = max(10, min(size.width, size.height) * 0.02)

        for index in 0..<starCount {
            let star = SKSpriteNode(texture: texture)
            let sizeMultiplier = Self.starSizeMultipliers[index % Self.starSizeMultipliers.count]
            let starWidth = baseWidth * sizeMultiplier * CGFloat.random(in: 0.88...1.12)
            let horizontalMargin = starWidth
            let verticalMargin = starWidth * aspectRatio

            star.name = "twinklingStar"
            star.size = CGSize(width: starWidth, height: starWidth * aspectRatio)
            star.position = CGPoint(
                x: CGFloat.random(in: horizontalMargin...max(horizontalMargin, size.width - horizontalMargin)),
                y: CGFloat.random(in: verticalMargin...max(verticalMargin, size.height - verticalMargin))
            )
            star.zRotation = CGFloat.random(in: -0.14...0.14)
            star.alpha = CGFloat.random(in: 0.08...0.28)
            star.setScale(CGFloat.random(in: 0.72...0.86))
            starFieldNode.addChild(star)
            runTwinkleAnimation(on: star)
        }
    }

    private func runTwinkleAnimation(on star: SKSpriteNode) {
        let initialDelay = SKAction.wait(forDuration: TimeInterval.random(in: 0...1.8))
        let brightenDuration = TimeInterval.random(in: 0.38...0.82)
        let dimDuration = TimeInterval.random(in: 0.42...0.9)
        let brightAlpha = CGFloat.random(in: 0.68...1.0)
        let dimAlpha = CGFloat.random(in: 0.06...0.24)

        let brighten = SKAction.group([
            .fadeAlpha(to: brightAlpha, duration: brightenDuration),
            .scale(to: CGFloat.random(in: 0.96...1.08), duration: brightenDuration)
        ])
        brighten.timingMode = .easeInEaseOut

        let dim = SKAction.group([
            .fadeAlpha(to: dimAlpha, duration: dimDuration),
            .scale(to: CGFloat.random(in: 0.72...0.86), duration: dimDuration)
        ])
        dim.timingMode = .easeInEaseOut

        let twinkle = SKAction.sequence([
            brighten,
            .wait(forDuration: TimeInterval.random(in: 0.08...0.26)),
            dim,
            .wait(forDuration: TimeInterval.random(in: 0.35...1.35))
        ])
        star.run(.sequence([initialDelay, .repeatForever(twinkle)]))
    }
}
