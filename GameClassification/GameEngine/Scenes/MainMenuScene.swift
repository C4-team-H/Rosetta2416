//
//  MainMenuScene.swift
//  GameClassification
//
//  Created by Muhammad Muthi' Nuritzan on 13/07/26.
//

import SpriteKit

final class MainMenuScene: SKScene {

    private var titleLabel: SKLabelNode!
    private var startButton: SKShapeNode!
    private var newGameButton: SKShapeNode!
    private let coordinator: GameplayCoordinator

    init(size: CGSize, coordinator: GameplayCoordinator) {
        self.coordinator = coordinator
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMove(to view: SKView) {
        // 1. Mengatur warna background menu utama
        self.backgroundColor = SKColor(red: 0.1, green: 0.12, blue: 0.18, alpha: 1.0) // Slate dark blue
        
        // 2. Membuat Label Judul Game
        titleLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        titleLabel.text = "DRAWING SPACE"
        titleLabel.fontSize = 36
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: self.size.width / 2, y: self.size.height * 0.68)
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .center
        self.addChild(titleLabel)
        
        startButton = makeButton(
            name: "startButton",
            title: "CONTINUE GAME",
            color: SKColor(red: 0.15, green: 0.68, blue: 0.38, alpha: 1)
        )
        newGameButton = makeButton(
            name: "newGameButton",
            title: "NEW GAME",
            color: SKColor(red: 0.16, green: 0.44, blue: 0.72, alpha: 1)
        )
        positionMenuNodes()
        self.addChild(startButton)
        self.addChild(newGameButton)
    }
    
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        
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
        guard let view else { return }
        coordinator.continueGame(in: view, size: size)
    }

    private func startNewGame() {
        guard let view else { return }
        coordinator.startNewGame(in: view, size: size)
    }

    private func makeButton(name: String, title: String, color: SKColor) -> SKShapeNode {
        let button = SKShapeNode(rectOf: CGSize(width: 220, height: 58), cornerRadius: 12)
        button.name = name
        button.fillColor = color
        button.strokeColor = .white
        button.lineWidth = 2

        let label = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        label.text = title
        label.fontSize = 18
        label.fontColor = .white
        label.name = name
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        button.addChild(label)
        return button
    }

    private func positionMenuNodes() {
        titleLabel?.position = CGPoint(x: size.width / 2, y: size.height * 0.68)
        startButton?.position = CGPoint(x: size.width / 2, y: size.height * 0.48)
        newGameButton?.position = CGPoint(x: size.width / 2, y: size.height * 0.28)
    }
}
