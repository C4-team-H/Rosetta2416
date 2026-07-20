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
    private(set) var currentRoom: RoomID?
    private(set) var showLowEnergyAlert: Bool = false
    private var hasTriggeredLowEnergyAlert: Bool = false

    let storySystem: StoryProgressionSystem
    private var energySystem: EnergySystem
    private let dialogueManager: AIDialogueManager
    private let repository: StoryProgressRepository
    private let safeSpawnProvider: (CheckpointID) -> CGPoint
    private var checkpointSystem: CheckpointSystem
    private var sessionRevision = 0

    init(
        localPlayer: PlayerState,
        storySystem: StoryProgressionSystem? = nil,
        repository: StoryProgressRepository? = nil,
        dialogueManager: AIDialogueManager? = nil,
        safeSpawnProvider: ((CheckpointID) -> CGPoint)? = nil
    ) {
        let storySystem = storySystem ?? StoryProgressionSystem()
        self.localPlayer = localPlayer
        self.storySystem = storySystem
        self.repository = repository ?? InMemoryStoryProgressRepository()
        self.dialogueManager = dialogueManager ?? AIDialogueManager()
        self.safeSpawnProvider = safeSpawnProvider ?? { GameMapLayout.safeSpawn(for: $0) }
        let energySystem = EnergySystem(playerID: localPlayer.id)
        self.energySystem = energySystem
        checkpointSystem = CheckpointSystem(initialSnapshot: StorySaveSnapshot(
            sharedStory: storySystem.state,
            localSurvival: energySystem.state,
            safeSpawn: localPlayer.worldPosition,
            stats: GameSessionStats()
        ))
    }

    var sharedStory: StoryState { storySystem.state }
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
        currentRoom = nil
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
            updateLowEnergyState()
            AudioManager.shared.updateBackgroundMusic(forEnergy: energy)
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
        updateLowEnergyState()
        AudioManager.shared.updateBackgroundMusic(forEnergy: energy)
    }

    func restoreFoodEnergy() {
        _ = handle(.foodCompleted)
    }

    func recordSuccessfulDrawing() {
        stats.successfulDrawings += 1
    }

    func markAlbumOpened() {
        let effects = storySystem.markAlbumOpened()
        guard !effects.isEmpty else { return }
        applyEffects(effects)
    }

    func updateLocalPlayer(position: CGPoint) {
        guard position.isFinite, localPlayer.worldPosition != position else { return }
        localPlayer.worldPosition = position
    }

    func updateCurrentRoom(_ room: RoomID?) {
        currentRoom = room
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

    func dismissLowEnergyAlert() {
        showLowEnergyAlert = false
    }

    private func updateLowEnergyState() {
        if energy <= 20.0 {
            if !hasTriggeredLowEnergyAlert {
                hasTriggeredLowEnergyAlert = true
                showLowEnergyAlert = true
                AudioManager.shared.playWrongSound()
            }
        } else {
            hasTriggeredLowEnergyAlert = false
            showLowEnergyAlert = false
        }
    }

    func loadProgress() async {
        let revisionAtLoadStart = sessionRevision
        do {
            guard let persisted = try await repository.load() else { return }
            guard revisionAtLoadStart == sessionRevision else { return }
            storySystem.restore(persisted.latest.sharedStory)
            energySystem.restore(persisted.latest.localSurvival)
            localPlayer.worldPosition = persisted.latest.safeSpawn.isFinite
                ? persisted.latest.safeSpawn
                : safeSpawn(for: persisted.latest.sharedStory.latestCheckpoint)
            currentRoom = nil
            stats = persisted.latest.stats
            checkpointSystem.restoreRecord(persisted.checkpoint)
            updateLowEnergyState()
            AudioManager.shared.updateBackgroundMusic(forEnergy: energy)
        } catch {
            transientMessage = "Saved progress could not be restored. A new session was started."
        }
    }

    func retryCheckpoint() {
        let checkpoint = checkpointSystem.latestCheckpoint
        storySystem.restore(checkpoint.sharedStory)
        energySystem.restoreCheckpoint(checkpoint.localSurvival)
        localPlayer.worldPosition = checkpointSystem.restorationSpawn(
            fallback: safeSpawn(for: checkpoint.sharedStory.latestCheckpoint)
        )
        currentRoom = nil
        stats = checkpoint.stats
        phase = .playing
        currentDialogue = nil
        transientMessage = "Checkpoint restored"
        hasTriggeredLowEnergyAlert = false
        showLowEnergyAlert = false
        persistLatest()
        updateLowEnergyState()
        AudioManager.shared.updateBackgroundMusic(forEnergy: energy)
    }

    func startNewSession(clearSavedProgress: Bool = true) {
        sessionRevision += 1
        _ = storySystem.handle(.newSession)
        energySystem = EnergySystem(playerID: localPlayer.id)
        localPlayer.worldPosition = safeSpawn(for: .sleepingRoomStart)
        currentRoom = nil
        stats = GameSessionStats()
        phase = .playing
        currentDialogue = nil
        transientMessage = nil
        checkpointNotice = nil
        hasTriggeredLowEnergyAlert = false
        showLowEnergyAlert = false

        if let line = dialogueManager.nextLine(for: .chapterEntered(.sleepingRoom), story: storySystem.state) {
            currentDialogue = line
            storySystem.markDialogueDelivered(id: line.id)
        }

        checkpointSystem.record(makeSnapshot(safeSpawn: safeSpawn(for: .sleepingRoomStart)))
        let progress = PersistedStoryProgress(latest: makeSnapshot(), checkpoint: checkpointSystem.latestCheckpoint)
        Task {
            if clearSavedProgress { try? await repository.clear() }
            try? await repository.save(progress)
        }
        updateLowEnergyState()
        AudioManager.shared.updateBackgroundMusic(forEnergy: energy)
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
                    updateLowEnergyState()
                }
                shouldPersist = true

            case let .checkpointReached(checkpoint):
                checkpointNotice = checkpoint
                checkpointSystem.record(makeSnapshot(safeSpawn: safeSpawn(for: checkpoint)))
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
        let progress = PersistedStoryProgress(latest: makeSnapshot(), checkpoint: checkpointSystem.latestCheckpoint)
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
        safeSpawnProvider(checkpoint)
    }
}
