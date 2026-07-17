import PencilKit
import SpriteKit
import UIKit

@MainActor
final class GameplayCoordinator {
    let sessionState: GameSessionState
    let tacticalMapViewModel: TacticalMapViewModel
    let authority: StoryAuthority
    let missionSystem: MissionSystem

    weak var presentingViewController: UIViewController?
    private weak var activeGameScene: GameScene?

    init() {
        let repository: StoryProgressRepository
        do {
            repository = try LocalStoryProgressRepository()
        } catch {
            repository = InMemoryStoryProgressRepository()
        }

        let storySystem = StoryProgressionSystem()
        let session = GameSessionState(
            localPlayer: PlayerState(
                id: "local-player",
                name: "You",
                worldPosition: GameMapLayout.playerSpawnPosition,
                isConnected: true
            ),
            storySystem: storySystem,
            repository: repository
        )
        sessionState = session
        tacticalMapViewModel = TacticalMapViewModel(sessionState: session)
        missionSystem = MissionSystem(story: storySystem)
        authority = LocalStoryAuthority(sessionState: session, recognizer: CoreMLDoodleRecognizer())
    }

    func loadProgress() async {
        await sessionState.loadProgress()
    }

    func makeMainMenuScene(size: CGSize) -> MainMenuScene {
        MainMenuScene(size: size, coordinator: self)
    }

    func makeGameScene(size: CGSize) -> GameScene {
        let scene = GameScene(size: size, sessionState: sessionState, tacticalMapViewModel: tacticalMapViewModel)
        scene.eventDelegate = self
        activeGameScene = scene
        return scene
    }

    func continueGame(in view: SKView, size: CGSize) {
        presentFreshGameScene(in: view, size: size)
    }

    func startNewGame(in view: SKView, size: CGSize) {
        tacticalMapViewModel.closeMap()
        sessionState.startNewSession()
        presentFreshGameScene(in: view, size: size)
    }

    func retryCheckpoint() {
        AudioManager.shared.playButtonSound()
        if sessionState.phase == .gameOver {
            guard let presenter = presentingViewController, presenter.presentedViewController == nil else { return }
            sessionState.beginDrawing(objectiveID: "retry-angel")
            
            let challenge = DrawingChallenge(
                id: "retry-angel",
                label: "angel",
                displayName: "ANGEL"
            )
            
            let controller = DrawingChallengeViewController()
            controller.challenge = challenge
            controller.challengeIndex = 1
            controller.totalChallenges = 1
            controller.modalPresentationStyle = .overFullScreen
            controller.modalTransitionStyle = .crossDissolve
            
            controller.onSubmit = { [weak self] drawing in
                guard let self else {
                    return DrawingSubmissionOutcome(accepted: false, message: "Game session ended.", recognition: nil)
                }
                let command = StoryCommand.submitDrawing(
                    commandID: UUID(),
                    objectiveID: challenge.id,
                    drawingData: drawing.dataRepresentation(),
                    playerID: sessionState.localPlayer.id
                )
                let result = await authority.execute(command)
                return DrawingSubmissionOutcome(accepted: result.accepted, message: result.message, recognition: result.recognition)
            }
            
            controller.onSuccess = { [weak self] in
                guard let self else { return }
                _ = self.sessionState.handle(.checkpointRetryRequested)
                self.activeGameScene?.restorePlayerFromSession()
            }
            
            controller.onCancel = { [weak self] in
                self?.sessionState.endDrawing()
            }
            
            presenter.present(controller, animated: true)
        } else {
            _ = sessionState.handle(.checkpointRetryRequested)
            presentingViewController?.dismiss(animated: true)
            activeGameScene?.restorePlayerFromSession()
        }
    }

    func playAgain() {
        AudioManager.shared.playButtonSound()
        guard let scene = activeGameScene, let view = scene.view else { return }
        tacticalMapViewModel.closeMap()
        sessionState.startNewSession()
        presentingViewController?.dismiss(animated: true)
        presentFreshGameScene(in: view, size: scene.size)
    }

    func returnToMainMenu() {
        AudioManager.shared.playButtonSound()
        presentingViewController?.dismiss(animated: true)
        guard let scene = activeGameScene, let view = scene.view else { return }
        sessionState.endGameplay()
        AudioManager.shared.stopBackgroundMusic()
        let menu = makeMainMenuScene(size: scene.size)
        menu.scaleMode = .resizeFill
        view.presentScene(menu, transition: .fade(withDuration: 0.6))
    }

    private func presentFreshGameScene(in view: SKView, size: CGSize) {
        let gameScene = makeGameScene(size: size)
        gameScene.scaleMode = .resizeFill
        view.presentScene(gameScene, transition: .fade(withDuration: 0.8))
        AudioManager.shared.playBackgroundMusic()
    }

    private func presentDrawingChallenge(_ challenge: DrawingChallenge, in scene: GameScene, chapterCount: Int, chapterIndex: Int) {
        guard let presenter = presentingViewController, presenter.presentedViewController == nil else { return }
        sessionState.beginDrawing(objectiveID: challenge.id)

        let controller = DrawingChallengeViewController()
        controller.challenge = challenge
        controller.challengeIndex = chapterIndex
        controller.totalChallenges = chapterCount
        controller.modalPresentationStyle = .overFullScreen
        controller.modalTransitionStyle = .crossDissolve

        controller.onSubmit = { [weak self, weak scene] drawing in
            guard let self else {
                return DrawingSubmissionOutcome(accepted: false, message: "Game session ended.", recognition: nil)
            }
            let command = StoryCommand.submitDrawing(
                commandID: UUID(),
                objectiveID: challenge.id,
                drawingData: drawing.dataRepresentation(),
                playerID: sessionState.localPlayer.id
            )
            let result = await authority.execute(command)
            scene?.applyStoryEffects(result.effects)
            return DrawingSubmissionOutcome(accepted: result.accepted, message: result.message, recognition: result.recognition)
        }

        controller.onSuccess = { [weak self, weak scene] in
            self?.sessionState.endDrawing()
            scene?.refreshStoryVisuals()
        }
        controller.onCancel = { [weak self] in self?.sessionState.endDrawing() }
        presenter.present(controller, animated: true)
    }

    private func presentAlbumBook() {
        guard let presenter = presentingViewController, presenter.presentedViewController == nil else { return }
        sessionState.markAlbumOpened()
        let controller = AlbumBookViewController()
        controller.modalPresentationStyle = .overFullScreen
        controller.modalTransitionStyle = .crossDissolve
        presenter.present(controller, animated: true)
    }
}

extension GameplayCoordinator: GameSceneEventDelegate {
    func gameScene(_ scene: GameScene, didEnter room: RoomID) {
        scene.applyStoryEffects(sessionState.handle(.roomEntered(room)))
    }

    func gameScene(_ scene: GameScene, didRequestObjective objectiveID: String) {
        guard let definition = missionSystem.interactableObjective(
            id: objectiveID,
            from: GameMapLayout.room(containing: sessionState.localPlayer.worldPosition)
        ) else { return }

        switch definition.kind {
        case .drawing:
            let chapterObjectives = StoryContent.objectives.filter { $0.chapter == definition.chapter }
            let index = (chapterObjectives.firstIndex(where: { $0.id == objectiveID }) ?? 0) + 1
            presentDrawingChallenge(
                DrawingChallenge(objective: definition),
                in: scene,
                chapterCount: chapterObjectives.count,
                chapterIndex: index
            )

        case let .easel(easelDef):
            guard let prompt = sessionState.storySystem.currentEaselPrompt(for: objectiveID) else { return }
            let completedCount = sessionState.storySystem.easelCompletedCount(for: objectiveID)
            let challenge = DrawingChallenge(
                id: objectiveID,
                label: prompt.expectedLabel,
                displayName: prompt.displayName,
                confidenceThreshold: prompt.confidenceThreshold
            )
            presentDrawingChallenge(challenge, in: scene, chapterCount: easelDef.count, chapterIndex: completedCount + 1)

        default:
            return
        }
    }

    func gameSceneDidRequestFoodChallenge(_ scene: GameScene) {
        let drawnLabels = Set(sessionState.storySystem.state.kitchenCompletedLabels)
        let available = DrawingChallenge.foodPool.filter { !drawnLabels.contains($0.label) }
        guard let challenge = available.randomElement() else { return }
        presentDrawingChallenge(challenge, in: scene, chapterCount: 1, chapterIndex: 1)
    }

    func gameSceneDidReachGameOver(_ scene: GameScene) {
        if presentingViewController?.presentedViewController is DrawingChallengeViewController {
            presentingViewController?.dismiss(animated: true)
        }
    }

    func gameSceneDidRequestAlbum(_ scene: GameScene) {
        presentAlbumBook()
    }
}
