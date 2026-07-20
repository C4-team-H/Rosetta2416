//
//  GameViewController.swift
//  GameClassification
//
//  Created by Muhammad Muthi' Nuritzan on 09/07/26.
//

import UIKit
import SpriteKit
import SwiftUI

class GameViewController: UIViewController {

    private let coordinator = GameplayCoordinator()
    private var overlayController: UIHostingController<GameplayHUDView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        coordinator.presentingViewController = self

        guard let spriteView = view as? SKView else {
            assertionFailure("GameViewController requires an SKView root view")
            return
        }

        let scene = coordinator.makeMainMenuScene(size: spriteView.bounds.size)
        scene.scaleMode = .resizeFill
        spriteView.presentScene(scene)
        spriteView.ignoresSiblingOrder = true
        spriteView.showsFPS = true
        spriteView.showsNodeCount = true

        installGameplayOverlay()
        Task { await coordinator.loadProgress() }
    }

    private func installGameplayOverlay() {
        let viewModel = coordinator.tacticalMapViewModel
        #if DEBUG
        let rootView = GameplayHUDView(
            viewModel: viewModel,
            session: coordinator.sessionState,
            mapDebugViewModel: coordinator.mapDebugViewModel,
            onRetryCheckpoint: { [weak coordinator] in coordinator?.retryCheckpoint() },
            onPlayAgain: { [weak coordinator] in coordinator?.playAgain() },
            onMainMenu: { [weak coordinator] in coordinator?.returnToMainMenu() }
        )
        #else
        let rootView = GameplayHUDView(
            viewModel: viewModel,
            session: coordinator.sessionState,
            onRetryCheckpoint: { [weak coordinator] in coordinator?.retryCheckpoint() },
            onPlayAgain: { [weak coordinator] in coordinator?.playAgain() },
            onMainMenu: { [weak coordinator] in coordinator?.returnToMainMenu() }
        )
        #endif
        let controller = UIHostingController(rootView: rootView)
        controller.view.backgroundColor = .clear
        controller.view.translatesAutoresizingMaskIntoConstraints = false

        let container = MapOverlayContainerView(
            viewModel: viewModel,
            debugSettings: coordinator.debugSettings
        )
        container.backgroundColor = .clear
        container.translatesAutoresizingMaskIntoConstraints = false

        addChild(controller)
        view.addSubview(container)
        container.addSubview(controller.view)
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            container.topAnchor.constraint(equalTo: view.topAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            controller.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: container.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        controller.didMove(toParent: self)
        overlayController = controller
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
