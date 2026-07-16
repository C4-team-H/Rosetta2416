import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
final class GameSessionState {
    private(set) var phase: GamePhase = .preparing
    private(set) var localPlayer: PlayerState
    private(set) var teammate: PlayerState?
    private(set) var teammateConnectionState: TeammateConnectionState = .disconnected
    private(set) var currentDialogue: AIDialogueLine?
    private(set) var transientMessage: String?
    private(set) var checkpointNotice: CheckpointID?
    private(set) var stats = GameSessionStats()

    let storySystem: StoryProgressionSystem
    private var energySystem: EnergySystem
    private let dialogueManager: AIDialogueManager
    private let repository: StoryProgressRepository
    private var checkpointSnapshot: StorySaveSnapshot
    private var sessionRevision = 0

    init(
        localPlayer: PlayerState,
        storySystem: StoryProgressionSystem? = nil,
        repository: StoryProgressRepository? = nil,
        dialogueManager: AIDialogueManager? = nil
    ) {
        let storySystem = storySystem ?? StoryProgressionSystem()
        self.localPlayer = localPlayer
        self.storySystem = storySystem
        self.repository = repository ?? InMemoryStoryProgressRepository()
        self.dialogueManager = dialogueManager ?? AIDialogueManager()
        let energySystem = EnergySystem(playerID: localPlayer.id)
        self.energySystem = energySystem
        checkpointSnapshot = StorySaveSnapshot(
            sharedStory: storySystem.state,
            localSurvival: energySystem.state,
            safeSpawn: localPlayer.worldPosition,
            stats: GameSessionStats()
        )
    }

    var sharedStory: SharedStoryState { storySystem.state }
    var survival: PlayerSurvivalState { energySystem.state }
    var objectives: [StoryObjective] { storySystem.objectives }
    var activeObjective: StoryObjective? { storySystem.activeObjective }
    var energy: Double { energySystem.state.energy }
    var progress: StoryProgress {
        StoryProgress(
            energy: energySystem.state.energy,
            intelligence: storySystem.state.intelligence,
            engineProgress: storySystem.state.engineProgress
        )
    }

    func beginGameplay() {
        phase = .playing
        if storySystem.state.currentChapter == .sleepingRoom {
            applyEffects([.dialogue(.chapterEntered(.sleepingRoom))])
        }
    }

    func endGameplay() {
        phase = .preparing
    }

    func beginDrawing(objectiveID: String) {
        guard phase == .playing else { return }
        phase = .drawing(objectiveID)
        stats.drawingAttempts += 1
    }

    func endDrawing() {
        guard case .drawing = phase else { return }
        phase = .playing
    }

    func endCutscene() {
        guard case .cutscene = phase else { return }
        phase = .playing
    }

    @discardableResult
    func handle(_ event: StoryEvent) -> [StoryEffect] {
        switch event {
        case .foodCompleted:
            energySystem.restoreFood()
            stats.kitchenRestores += 1
            persistLatest()
            return []
        case .checkpointRetryRequested:
            retryCheckpoint()
            return []
        default:
            break
        }
        let effects = storySystem.handle(event)
        if case .drawingValidated = event {
            let accepted = !effects.contains {
                if case .interactionDenied = $0 { return true }
                return false
            }
            if accepted {
                stats.successfulDrawings += 1
            }
        }
        applyEffects(effects)
        return effects
    }

    func updateEnergy(deltaTime: TimeInterval, isMoving: Bool) {
        guard phase == .playing || isDrawing else { return }
        stats.elapsedTime += max(0, deltaTime)
        if energySystem.update(deltaTime: deltaTime, isMoving: isMoving) {
            applyEffects(storySystem.handle(.energyDepleted))
        }
    }

    func restoreFoodEnergy() {
        _ = handle(.foodCompleted)
    }

    func recordSuccessfulDrawing() {
        stats.successfulDrawings += 1
    }

    func updateLocalPlayer(position: CGPoint) {
        guard position.isFinite, localPlayer.worldPosition != position else { return }
        localPlayer.worldPosition = position
    }

    func updateTeammate(position: CGPoint?, connectionState: TeammateConnectionState, name: String? = nil) {
        let cleanName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let teammateName = cleanName.flatMap { $0.isEmpty ? nil : $0 } ?? "Teammate"

        if teammate == nil, let position, position.isFinite {
            teammate = PlayerState(
                id: "teammate",
                name: teammateName,
                worldPosition: position,
                isConnected: connectionState == .connected
            )
        } else {
            if let position, position.isFinite { teammate?.worldPosition = position }
            if let cleanName, !cleanName.isEmpty { teammate?.name = cleanName }
            teammate?.isConnected = connectionState == .connected
        }
        teammateConnectionState = connectionState
    }

    func clearTeammate() {
        teammate = nil
        teammateConnectionState = .disconnected
    }

    func clearTransientPresentation() {
        transientMessage = nil
        checkpointNotice = nil
    }

    func dismissCheckpointNotice() {
        checkpointNotice = nil
    }

    func dismissDialogue() {
        currentDialogue = nil
    }

    func loadProgress() async {
        let revisionAtLoadStart = sessionRevision
        do {
            guard let persisted = try await repository.load() else { return }
            guard revisionAtLoadStart == sessionRevision else { return }
            storySystem.restore(persisted.latest.sharedStory)
            energySystem.restore(persisted.latest.localSurvival)
            localPlayer.worldPosition = safeSpawn(for: persisted.latest.sharedStory.latestCheckpoint)
            stats = persisted.latest.stats
            checkpointSnapshot = persisted.checkpoint
        } catch {
            transientMessage = "Saved progress could not be restored. A new session was started."
        }
    }

    func retryCheckpoint() {
        storySystem.restore(checkpointSnapshot.sharedStory)
        energySystem.restoreCheckpoint(checkpointSnapshot.localSurvival)
        localPlayer.worldPosition = safeSpawn(for: checkpointSnapshot.sharedStory.latestCheckpoint)
        stats = checkpointSnapshot.stats
        phase = .playing
        currentDialogue = nil
        transientMessage = "Checkpoint restored"
        persistLatest()
    }

    func startNewSession(clearSavedProgress: Bool = true) {
        sessionRevision += 1
        _ = storySystem.handle(.newSession)
        energySystem = EnergySystem(playerID: localPlayer.id)
        localPlayer.worldPosition = safeSpawn(for: .sleepingRoom)
        stats = GameSessionStats()
        phase = .playing
        currentDialogue = nil
        transientMessage = nil
        checkpointNotice = nil

        if let line = dialogueManager.nextLine(for: .chapterEntered(.sleepingRoom), story: storySystem.state) {
            currentDialogue = line
            storySystem.markDialogueDelivered(id: line.id)
        }

        checkpointSnapshot = makeSnapshot(safeSpawn: safeSpawn(for: .sleepingRoom))
        let progress = PersistedStoryProgress(latest: makeSnapshot(), checkpoint: checkpointSnapshot)
        Task {
            if clearSavedProgress { try? await repository.clear() }
            try? await repository.save(progress)
        }
    }

    private var isDrawing: Bool {
        if case .drawing = phase { return true }
        return false
    }

    private func applyEffects(_ effects: [StoryEffect]) {
        guard !effects.isEmpty else { return }
        var shouldPersist = false

        for effect in effects {
            switch effect {
            case .objectiveCompleted:
                shouldPersist = true

            case .chapterChanged, .mapNeedsRefresh, .doorAccessChanged, .stationVisualChanged:
                shouldPersist = true

            case let .powerChanged(power):
                if power == .disrupted {
                    energySystem.applyElectricalDisruption()
                }
                shouldPersist = true

            case let .checkpointReached(checkpoint):
                checkpointNotice = checkpoint
                checkpointSnapshot = makeSnapshot(safeSpawn: safeSpawn(for: checkpoint))
                shouldPersist = true

            case let .cutscene(cutscene):
                phase = .cutscene(cutscene)

            case let .dialogue(trigger):
                if let line = dialogueManager.nextLine(for: trigger, story: storySystem.state) {
                    currentDialogue = line
                    storySystem.markDialogueDelivered(id: line.id)
                    shouldPersist = true
                }

            case let .interactionDenied(message):
                transientMessage = message

            case .gameOver:
                phase = .gameOver
                transientMessage = "Energy depleted"
                shouldPersist = true

            case .victory:
                phase = .victory
                shouldPersist = true
            }
        }

        if shouldPersist { persistLatest() }
    }

    private func persistLatest() {
        let progress = PersistedStoryProgress(latest: makeSnapshot(), checkpoint: checkpointSnapshot)
        Task { try? await repository.save(progress) }
    }

    private func makeSnapshot(safeSpawn: CGPoint? = nil) -> StorySaveSnapshot {
        StorySaveSnapshot(
            sharedStory: storySystem.state,
            localSurvival: energySystem.state,
            safeSpawn: safeSpawn ?? self.safeSpawn(for: storySystem.state.latestCheckpoint),
            stats: stats
        )
    }

    private func safeSpawn(for checkpoint: CheckpointID) -> CGPoint {
        GameMapLayout.safeSpawn(for: checkpoint)
    }
}
