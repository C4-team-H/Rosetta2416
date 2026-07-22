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
    private var startButton: SKSpriteNode!
    private var newGameButton: SKSpriteNode!
    private let coordinator: GameplayCoordinator

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
        
        startButton = makeImageButton(name: "startButton", imageName: "ContinueButton")
        newGameButton = makeImageButton(name: "newGameButton", imageName: "NewGameButton")
        positionMenuNodes()
        self.addChild(startButton)
        self.addChild(newGameButton)
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
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodesAtPoint = self.nodes(at: location)
        
        for node in nodesAtPoint {
            switch node.name {
            case "startButton":
                startGame()
                return
            case "newGameButton":
                startNewGame()
                return
            default:
                continue
            }
        }
    }

    private func startGame() {
        AudioManager.shared.playButtonSound()
        guard let view else { return }
        coordinator.continueGame(in: view, size: size)
    }

    private func startNewGame() {
        AudioManager.shared.playButtonSound()
        guard let view else { return }
        coordinator.startNewGame(in: view, size: size)
    }

    private func makeImageButton(name: String, imageName: String) -> SKSpriteNode {
        let button = SKSpriteNode(imageNamed: imageName)
        button.name = name
        let targetWidth = size.width / 4
        let targetHeight = targetWidth * (332.0 / 1390.0)
        button.size = CGSize(width: targetWidth, height: targetHeight)
        return button
    }

    private func positionMenuNodes() {
        positionBackgroundNode()
        titleLabel?.position = CGPoint(x: size.width / 2, y: size.height * 0.68)
        startButton?.position = CGPoint(x: size.width / 2, y: size.height * 0.24)
        newGameButton?.position = CGPoint(x: size.width / 2, y: size.height * 0.14)
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
}
