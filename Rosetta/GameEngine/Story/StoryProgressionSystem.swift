import Foundation
import Observation

@MainActor
protocol StoryProgressionManaging: AnyObject {
    var state: StoryState { get }
    var objectives: [StoryObjective] { get }
    var activeObjective: StoryObjective? { get }

    func canEnter(_ chapter: StoryChapter) -> Bool
    func canAccess(_ room: RoomID) -> Bool
    func handle(_ event: StoryEvent) -> [StoryEffect]
    func restore(_ state: StoryState)
    func markAlbumOpened() -> [StoryEffect]
}

@MainActor
@Observable
final class StoryProgressionSystem: StoryProgressionManaging {
    private(set) var state: StoryState
    let labelCatalog: CoreMLLabelCatalog
    private var challengeSystem: DrawingChallengeSystem
    private var albumBookSystem = AlbumBookSystem()

    init(state: StoryState? = nil, labelCatalog: CoreMLLabelCatalog? = nil) {
        let catalog = labelCatalog ?? CoreMLLabelCatalog()
        self.labelCatalog = catalog
        challengeSystem = DrawingChallengeSystem(catalog: catalog)
        self.state = state ?? .initial
        normalizeAndPrepareState()
    }

    var objectives: [StoryObjective] {
        StoryConfiguration.challenges.map { definition in
            StoryObjective(definition: objectiveDefinition(for: definition), status: status(for: definition))
        }
    }

    var activeObjective: StoryObjective? {
        guard let id = state.activeMission?.activeChallengeID else { return nil }
        return objectives.first { $0.id == id }
    }

    func definition(id: String) -> StoryObjectiveDefinition? {
        StoryConfiguration.definition(id: id).map(objectiveDefinition(for:))
    }

    func drawingDefinition(id: String) -> DrawingMissionDefinition? {
        StoryConfiguration.definition(id: id)
    }

    func currentPrompt(for challengeID: String) -> DrawingPrompt? {
        guard let definition = StoryConfiguration.definition(id: challengeID),
              let label = state.selectedChallengeLabels[challengeID] else { return nil }
        return DrawingPrompt(
            expectedLabel: label,
            displayName: label.uppercased(),
            confidenceThreshold: definition.confidenceThreshold
        )
    }

    // Compatibility for callers while the UI transitions from aggregated easels.
    func currentEaselPrompt(for objectiveID: String) -> DrawingPrompt? { currentPrompt(for: objectiveID) }
    func easelCompletedCount(for objectiveID: String) -> Int {
        state.completedChallengeIDs.contains(objectiveID) ? 1 : 0
    }

    func canEnter(_ chapter: StoryChapter) -> Bool {
        switch chapter {
        case .sleepingRoom: true
        case .laboratory: state.currentChapter.order >= StoryChapter.laboratory.order
        case .engineInitial: state.isEngineRoomUnlocked
        case .storage: state.isStorageUnlocked
        case .engineFinal: state.hasAdvancedRepairTools
        case .cockpit: state.isCockpitUnlocked && state.engineProgress == 100 && state.intelligence == 100
        case .victory: state.currentChapter == .victory
        }
    }

    func canAccess(_ room: RoomID) -> Bool {
        switch room {
        case .sleepingRoom, .laboratory, .kitchen: true
        case .engine: state.isEngineRoomUnlocked
        case .storage: state.isStorageUnlocked
        case .cockpit:
            state.isCockpitUnlocked
                && state.engineProgress == 100
                && state.intelligence == 100
                && state.hasAdvancedRepairTools
                && state.completedMissionIDs.contains(.continueEngineRepair)
        }
    }

    func handle(_ event: StoryEvent) -> [StoryEffect] {
        switch event {
        case let .roomEntered(room):
            return handleRoomEntry(room)

        case let .stationInteractionRequested(stationID):
            guard state.activeMission?.activeChallengeID == stationID else {
                return [.interactionDenied("This repair is not available yet.")]
            }
            return []

        case let .drawingValidated(challengeID, result):
            return validateDrawing(challengeID: challengeID, result: result)

        case let .drawingFailed(objectiveID):
            return recordDrawingFailure(challengeID: objectiveID, reason: "Drawing not recognized. Try again.")

        case .energyDepleted:
            return [.gameOver]

        case .foodCompleted, .checkpointRetryRequested:
            return []

        case .newSession:
            state = .initial
            return [
                .chapterChanged(.sleepingRoom),
                .powerChanged(.off),
                .checkpointReached(.sleepingRoomStart),
                .doorAccessChanged(.engine, isUnlocked: false),
                .doorAccessChanged(.storage, isUnlocked: false),
                .doorAccessChanged(.cockpit, isUnlocked: false),
                .mapNeedsRefresh,
                .dialogue(.chapterEntered(.sleepingRoom))
            ]
        }
    }

    func restore(_ state: StoryState) {
        self.state = state
        normalizeAndPrepareState()
    }

    func markDialogueDelivered(id: String) {
        state.deliveredDialogueIDs.insert(id)
    }

    func markAlbumOpened() -> [StoryEffect] {
        guard albumBookSystem.openBook(in: &state.albumBook) else { return [] }
        return [.mapNeedsRefresh]
    }

    func markCommandProcessed(id: UUID) -> Bool {
        state.processedCommandIDs.insert(id).inserted
    }

    private func validateDrawing(challengeID: String, result: RecognitionResult) -> [StoryEffect] {
        guard let definition = StoryConfiguration.definition(id: challengeID),
              state.activeMission?.activeChallengeID == challengeID,
              let expectedLabel = state.selectedChallengeLabels[challengeID],
              !state.completedChallengeIDs.contains(challengeID) else {
            return [.interactionDenied("This drawing challenge is not active.")]
        }

        switch challengeSystem.validate(result, for: definition, expectedLabel: expectedLabel) {
        case .accepted:
            albumBookSystem.recordDrawingSuccess(challengeID: challengeID, in: &state.albumBook)
            return completeChallenge(definition)
        case let .rejected(reason):
            return recordDrawingFailure(challengeID: challengeID, reason: reason)
        }
    }

    private func recordDrawingFailure(challengeID: String? = nil, reason: String) -> [StoryEffect] {
        var effects: [StoryEffect] = [.interactionDenied(reason)]
        let targetID = challengeID ?? state.activeMission?.activeChallengeID ?? "default"
        if albumBookSystem.recordDrawingFailure(challengeID: targetID, in: &state.albumBook) {
            state.deliveredDialogueIDs.remove("album-hint")
            effects += [.dialogue(.albumHint), .mapNeedsRefresh]
        }
        return effects
    }

    private func completeChallenge(_ definition: DrawingMissionDefinition) -> [StoryEffect] {
        guard state.completedChallengeIDs.insert(definition.id).inserted else { return [] }

        state.intelligence = (state.intelligence + definition.intelligenceReward).clamped(to: 0...100)
        let engineMaximum = state.hasAdvancedRepairTools ? 100.0 : 60.0
        state.engineProgress = (state.engineProgress + definition.engineReward).clamped(to: 0...engineMaximum)

        var effects: [StoryEffect] = [
            .objectiveCompleted(definition.id),
            .stationVisualChanged(definition.id, .completed),
            .mapNeedsRefresh
        ]
        effects += advanceStoryIfPossible()
        refreshActiveMission()
        return effects
    }

    private func advanceStoryIfPossible() -> [StoryEffect] {
        var effects: [StoryEffect] = []

        switch state.currentChapter {
        case .sleepingRoom:
            break

        case .laboratory:
            if completedAll(.laboratory) {
                state.intelligence = 40
                state.completedMissionIDs.insert(.restoreAI)
                state.currentChapter = .engineInitial
                state.isEngineRoomUnlocked = true
                prepareCurrentChapter()
                _ = markMilestone("laboratoryCompleted")
                state.latestCheckpoint = .laboratoryCompleted
                effects += [
                    .chapterChanged(.engineInitial),
                    .checkpointReached(.laboratoryCompleted),
                    .doorAccessChanged(.engine, isUnlocked: true),
                    .dialogue(.chapterEntered(.engineInitial)),
                    .mapNeedsRefresh
                ]
            }

        case .engineInitial:
            if state.engineProgress >= 10, markMilestone("engine10") {
                state.powerState = .basicPower
                state.latestCheckpoint = .engine10
                effects += [
                    .powerChanged(.basicPower),
                    .dialogue(.powerChanged(.basicPower)),
                    .checkpointReached(.engine10),
                    .mapNeedsRefresh
                ]
            }
            if state.engineProgress >= 40, markMilestone("engine40") {
                state.powerState = .disrupted
                state.latestCheckpoint = .engine40
                effects += [
                    .powerChanged(.disrupted),
                    .dialogue(.powerChanged(.disrupted)),
                    .cutscene(.electricalDisruption),
                    .checkpointReached(.engine40),
                    .mapNeedsRefresh
                ]
            }
            if completedAll(.engineInitial), markMilestone("engine60") {
                state.engineProgress = 60
                state.completedMissionIDs.insert(.repairEngine)
                state.currentChapter = .storage
                state.isStorageUnlocked = true
                prepareCurrentChapter()
                state.latestCheckpoint = .engine60
                effects += [
                    .chapterChanged(.storage),
                    .checkpointReached(.engine60),
                    .doorAccessChanged(.storage, isUnlocked: true),
                    .dialogue(.chapterEntered(.storage)),
                    .mapNeedsRefresh
                ]
            }

        case .storage:
            if completedAll(.storage), markMilestone("advancedTools") {
                state.completedMissionIDs.insert(.retrieveCalibrationTools)
                state.hasAdvancedRepairTools = true
                state.currentChapter = .engineFinal
                prepareCurrentChapter()
                state.latestCheckpoint = .advancedToolsAcquired
                effects += [
                    .chapterChanged(.engineFinal),
                    .checkpointReached(.advancedToolsAcquired),
                    .cutscene(.advancedToolsAcquired),
                    .dialogue(.chapterEntered(.engineFinal)),
                    .mapNeedsRefresh
                ]
            }

        case .engineFinal:
            if completedAll(.engineFinal), markMilestone("engine100") {
                state.engineProgress = 100
                state.intelligence = 100
                state.completedMissionIDs.insert(.continueEngineRepair)
                state.powerState = .fullyRestored
                state.isCockpitUnlocked = true
                state.currentChapter = .cockpit
                prepareCurrentChapter()
                state.latestCheckpoint = .engine100
                effects += [
                    .powerChanged(.fullyRestored),
                    .cutscene(.engineRestoration),
                    .chapterChanged(.cockpit),
                    .checkpointReached(.engine100),
                    .doorAccessChanged(.cockpit, isUnlocked: true),
                    .dialogue(.chapterEntered(.cockpit)),
                    .mapNeedsRefresh
                ]
            }

        case .cockpit:
            if completedAll(.cockpit), markMilestone("victory") {
                state.completedMissionIDs.insert(.initiateLaunch)
                state.currentChapter = .victory
                state.activeMission = nil
                effects += [.chapterChanged(.victory), .dialogue(.victory), .mapNeedsRefresh, .victory]
            }

        case .victory:
            break
        }

        return effects
    }

    private func handleRoomEntry(_ room: RoomID) -> [StoryEffect] {
        guard canAccess(room) else {
            return [.dialogue(.roomDenied(room)), .interactionDenied("Access denied.")]
        }

        var effects: [StoryEffect] = []

        if room == .laboratory, state.currentChapter == .sleepingRoom {
            state.completedMissionIDs.insert(.findLaboratory)
            state.currentChapter = .laboratory
            prepareCurrentChapter()
            refreshActiveMission()
            state.latestCheckpoint = .laboratoryEntered
            effects += [
                .chapterChanged(.laboratory),
                .checkpointReached(.laboratoryEntered),
                .dialogue(.chapterEntered(.laboratory)),
                .mapNeedsRefresh
            ]
        } else if room == .cockpit,
           state.currentChapter == .cockpit,
           markMilestone("cockpitEntered") {
            state.latestCheckpoint = .cockpitEntered
            effects += [.checkpointReached(.cockpitEntered)]
        }

        effects.append(.dialogue(.roomEntered(room)))

        return effects
    }

    private func prepareCurrentChapter() {
        challengeSystem.prepareLabels(for: state.currentChapter, state: &state)
        refreshActiveMission()
    }

    private func refreshActiveMission() {
        let activeChallengeID = StoryConfiguration.challenges(for: state.currentChapter)
            .first { !state.completedChallengeIDs.contains($0.id) }?.id
        state.activeMission = StoryConfiguration.mission(
            for: state.currentChapter,
            activeChallengeID: activeChallengeID
        )
    }

    private func status(for definition: DrawingMissionDefinition) -> ObjectiveStatus {
        if state.completedChallengeIDs.contains(definition.id) { return .completed }
        if definition.chapter == .engineFinal,
           state.currentChapter == .storage,
           !state.hasAdvancedRepairTools { return .blocked }
        guard definition.chapter == state.currentChapter else { return .locked }
        return state.activeMission?.activeChallengeID == definition.id ? .active : .locked
    }

    private func objectiveDefinition(for definition: DrawingMissionDefinition) -> StoryObjectiveDefinition {
        let label = state.selectedChallengeLabels[definition.id] ?? "unavailable"
        return StoryObjectiveDefinition(
            id: definition.id,
            chapter: definition.chapter,
            roomID: definition.roomID,
            title: "Repair the \(definition.roomID)",
            description: "Go to \(definition.id.split(separator: "-").map { $0.capitalized }.joined(separator: " ")) and fix it",
            requiredObjectiveIDs: [],
            reward: StoryProgressReward(
                intelligence: definition.intelligenceReward,
                engine: definition.engineReward
            ),
            kind: .drawing(DrawingPrompt(
                expectedLabel: label,
                displayName: label.uppercased(),
                confidenceThreshold: definition.confidenceThreshold
            )),
            priority: .main
        )
    }

    private func completedAll(_ chapter: StoryChapter) -> Bool {
        let IDs = StoryConfiguration.challenges(for: chapter).map(\.id)
        return !IDs.isEmpty && IDs.allSatisfy(state.completedChallengeIDs.contains)
    }

    private func markMilestone(_ id: String) -> Bool {
        state.processedMilestoneIDs.insert(id).inserted
    }

    private func normalizeAndPrepareState() {
        state.completedChallengeIDs.formIntersection(StoryConfiguration.challengeIDs)

        state.selectedChallengeLabels = state.selectedChallengeLabels.filter { challengeID, label in
            let normalizedLabel = label.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard let definition = StoryConfiguration.definition(id: challengeID),
                  labelCatalog.availableLabels.contains(normalizedLabel) else { return false }
            return labelCatalog.contains(normalizedLabel, in: definition.category)
                || labelCatalog.contains(normalizedLabel, in: definition.fallbackCategory)
        }

        var labCount = completedCount(.laboratory)
        if labCount < StoryConfiguration.laboratoryChallenges.count {
            removeCompletions(after: .laboratory)
        }

        var initialEngineCount = completedCount(.engineInitial)
        if initialEngineCount < StoryConfiguration.engineInitialChallenges.count {
            removeCompletions(after: .engineInitial)
        }
        var storageCount = completedCount(.storage)
        if storageCount < StoryConfiguration.storageChallenges.count {
            removeCompletions(after: .storage)
        }
        var finalEngineCount = completedCount(.engineFinal)
        if finalEngineCount < StoryConfiguration.engineFinalChallenges.count {
            removeCompletions(after: .engineFinal)
        }

        // Recompute after prerequisite pruning so malformed saves cannot skip gates.
        labCount = completedCount(.laboratory)
        initialEngineCount = completedCount(.engineInitial)
        storageCount = completedCount(.storage)
        finalEngineCount = completedCount(.engineFinal)

        state.intelligence = Double(10 + labCount * 10 + finalEngineCount * 15).clamped(to: 10...100)
        state.engineProgress = Double(initialEngineCount * 10 + finalEngineCount * 10).clamped(to: 0...100)

        state.hasAdvancedRepairTools = storageCount == StoryConfiguration.storageChallenges.count
        state.isEngineRoomUnlocked = labCount == StoryConfiguration.laboratoryChallenges.count
        state.isStorageUnlocked = initialEngineCount == StoryConfiguration.engineInitialChallenges.count
        state.isCockpitUnlocked = finalEngineCount == StoryConfiguration.engineFinalChallenges.count

        state.completedMissionIDs.removeAll()
        if state.currentChapter.order >= StoryChapter.laboratory.order || labCount > 0 {
            state.completedMissionIDs.insert(.findLaboratory)
        }
        if labCount == StoryConfiguration.laboratoryChallenges.count {
            state.completedMissionIDs.insert(.restoreAI)
        }
        if initialEngineCount == StoryConfiguration.engineInitialChallenges.count {
            state.completedMissionIDs.insert(.repairEngine)
        }
        if storageCount == StoryConfiguration.storageChallenges.count {
            state.completedMissionIDs.insert(.retrieveCalibrationTools)
        }
        if finalEngineCount == StoryConfiguration.engineFinalChallenges.count {
            state.completedMissionIDs.insert(.continueEngineRepair)
        }
        if completedAll(.cockpit) {
            state.completedMissionIDs.insert(.initiateLaunch)
        }

        if completedAll(.cockpit) {
            state.currentChapter = .victory
        } else if state.isCockpitUnlocked {
            state.currentChapter = .cockpit
        } else if state.hasAdvancedRepairTools {
            state.currentChapter = .engineFinal
        } else if state.isStorageUnlocked {
            state.currentChapter = .storage
        } else if state.isEngineRoomUnlocked {
            state.currentChapter = .engineInitial
        } else if state.currentChapter.order >= StoryChapter.laboratory.order {
            state.currentChapter = .laboratory
        } else {
            state.currentChapter = .sleepingRoom
        }

        if state.engineProgress >= 100 {
            state.powerState = .fullyRestored
        } else if state.engineProgress >= 40 {
            state.powerState = .disrupted
        } else if state.engineProgress >= 10 {
            state.powerState = .basicPower
        } else {
            state.powerState = .off
        }

        if state.engineProgress >= 10 { state.processedMilestoneIDs.insert("engine10") }
        if state.engineProgress >= 40 { state.processedMilestoneIDs.insert("engine40") }
        if state.engineProgress >= 60 { state.processedMilestoneIDs.insert("engine60") }
        if state.hasAdvancedRepairTools { state.processedMilestoneIDs.insert("advancedTools") }
        if state.engineProgress >= 100 { state.processedMilestoneIDs.insert("engine100") }
        if state.currentChapter == .victory { state.processedMilestoneIDs.insert("victory") }

        prepareCurrentChapter()
    }

    private func completedCount(_ chapter: StoryChapter) -> Int {
        StoryConfiguration.challenges(for: chapter)
            .filter { state.completedChallengeIDs.contains($0.id) }.count
    }

    private func removeCompletions(after chapter: StoryChapter) {
        let invalidIDs = StoryConfiguration.challenges
            .filter { $0.chapter.order > chapter.order }
            .map(\.id)
        state.completedChallengeIDs.subtract(invalidIDs)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
