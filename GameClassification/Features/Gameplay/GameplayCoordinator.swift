import PencilKit
import SpriteKit
import SwiftUI
import UIKit

@MainActor
final class GameplayCoordinator {
    let sessionState: GameSessionState
    let tacticalMapViewModel: TacticalMapViewModel
    let geometryStore: MapGeometryStore
    let debugSettings: GameDebugSettings
    let mapCoordinateConverter: MapEditorCoordinateConverter
    let authority: StoryAuthority
    let missionSystem: MissionSystem
    #if DEBUG
    let mapGeometryRepository: MapGeometryRepository?
    let mapDebugViewModel: MapDebugViewModel
    #endif

    weak var presentingViewController: UIViewController?
    private weak var activeGameScene: GameScene?
    private var previousFoodChallengeLabel: String?

    init() {
        let geometryStore = MapGeometryStore()
        let debugSettings = GameDebugSettings()
        let coordinateConverter = MapEditorCoordinateConverter()
        #if DEBUG
        let mapRepository = try? LocalMapGeometryRepository()

        if debugSettings.isMapDebugEnabled {
            do {
                if let draft = try mapRepository?.load() {
                    geometryStore.replaceConfiguration(
                        draft,
                        source: .debugDraft,
                        recordHistory: false
                    )
                    geometryStore.markSaved(source: .debugDraft)
                }
            } catch {
                geometryStore.statusMessage = "Debug draft ignored: \(error.localizedDescription)"
            }
        }
        #endif

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
                worldPosition: geometryStore.configuration.spawnPoint(for: .sleepingRoom)
                    ?? GameMapLayout.playerSpawnPosition,
                isConnected: true
            ),
            storySystem: storySystem,
            repository: repository,
            safeSpawnProvider: { checkpoint in
                geometryStore.configuration.safeSpawn(for: checkpoint)
            }
        )
        self.geometryStore = geometryStore
        self.debugSettings = debugSettings
        mapCoordinateConverter = coordinateConverter
        #if DEBUG
        mapGeometryRepository = mapRepository
        #endif
        sessionState = session
        tacticalMapViewModel = TacticalMapViewModel(
            sessionState: session,
            geometryStore: geometryStore
        )
        tacticalMapViewModel.gameDebugSettings = debugSettings
        missionSystem = MissionSystem(story: storySystem)
        authority = LocalStoryAuthority(sessionState: session, recognizer: CoreMLDoodleRecognizer())
        #if DEBUG
        mapDebugViewModel = MapDebugViewModel(
            store: geometryStore,
            settings: debugSettings,
            converter: coordinateConverter,
            repository: mapRepository,
            sessionState: session
        )
        #endif
    }

    func loadProgress() async {
        await sessionState.loadProgress()
    }

    func makeMainMenuScene(size: CGSize) -> MainMenuScene {
        MainMenuScene(size: size, coordinator: self)
    }

    func makeGameScene(size: CGSize) -> GameScene {
        let scene = GameScene(
            size: size,
            sessionState: sessionState,
            tacticalMapViewModel: tacticalMapViewModel,
            geometryStore: geometryStore,
            debugSettings: debugSettings,
            mapCoordinateConverter: mapCoordinateConverter
        )
        scene.eventDelegate = self
        #if DEBUG
        mapDebugViewModel.onResetPlayerToSpawn = { [weak scene] in
            scene?.resetPlayerToDebugSpawn()
        }
        mapDebugViewModel.onRebuildCollision = { [weak scene] in
            scene?.forceMapGeometryRefresh()
        }
        #endif
        activeGameScene = scene
        return scene
    }

    func continueGame(in view: SKView, size: CGSize) {
        presentFreshGameScene(in: view, size: size)
    }

    func startNewGame(in view: SKView, size: CGSize) {
        tacticalMapViewModel.closeMap()
        presentPrologScene(in: view, size: size)
    }

    private func presentPrologScene(in view: SKView, size: CGSize) {
        let prologScene = PrologScene(size: size) { [weak self, weak view] in
            guard let self, let view else { return }
            self.sessionState.startNewSession()
            self.presentFreshGameScene(in: view, size: size)
        }
        prologScene.scaleMode = .resizeFill
        view.presentScene(prologScene, transition: .fade(withDuration: 0.6))
    }

    func retryCheckpoint() {
        AudioManager.shared.playButtonSound()
        _ = sessionState.handle(.checkpointRetryRequested)
        presentingViewController?.dismiss(animated: true)
        activeGameScene?.restorePlayerFromSession()
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
        AudioManager.shared.playMainMenuMusic()
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
        let controller = UIHostingController(rootView: AlbumBookView())
        controller.modalPresentationStyle = .overFullScreen
        controller.modalTransitionStyle = .crossDissolve
        presenter.present(controller, animated: true)
    }
}

extension GameplayCoordinator: GameSceneEventDelegate {
    func gameScene(_ scene: GameScene, didEnter room: RoomID) {
        scene.applyStoryEffects(sessionState.handle(.roomEntered(room)))
    }

    func gameScene(_ scene: GameScene, didExit room: RoomID) {
        // Room occupancy is already cleared by GameScene. Story progression is
        // intentionally entry-driven, so an exit has no story side effect.
    }

    func gameScene(_ scene: GameScene, didRequestObjective objectiveID: String) {
        guard let definition = missionSystem.interactableObjective(
            id: objectiveID,
            from: GameMapLayout.room(containing: sessionState.localPlayer.worldPosition)
        ) else { return }

        switch definition.kind {
        case .drawing:
            let chapterObjectives = StoryConfiguration.challenges(for: definition.chapter)
            let index = (chapterObjectives.firstIndex(where: { $0.id == objectiveID }) ?? 0) + 1
            presentDrawingChallenge(
                DrawingChallenge(objective: definition),
                in: scene,
                chapterCount: chapterObjectives.count,
                chapterIndex: index
            )

        default:
            return
        }
    }

    func gameSceneDidRequestFoodChallenge(_ scene: GameScene) {
        guard let selection = try? DrawingChallengeRandomizer(catalog: sessionState.storySystem.labelCatalog)
            .randomFoodChallenge(excluding: previousFoodChallengeLabel) else { return }
        previousFoodChallengeLabel = selection.label
        let challenge = DrawingChallenge(
            id: "kitchen-\(selection.label)",
            label: selection.label,
            displayName: selection.label.uppercased()
        )
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
