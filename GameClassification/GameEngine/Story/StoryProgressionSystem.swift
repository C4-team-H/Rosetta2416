import Foundation
import Observation

@MainActor
protocol StoryProgressionManaging: AnyObject {
    var state: SharedStoryState { get }
    var objectives: [StoryObjective] { get }
    var activeObjective: StoryObjective? { get }

    func canEnter(_ chapter: StoryChapter) -> Bool
    func canAccess(_ room: RoomID) -> Bool
    func handle(_ event: StoryEvent) -> [StoryEffect]
    func completeObjective(id: String) -> [StoryEffect]
    func advanceStoryIfPossible() -> [StoryEffect]
    func restore(_ state: SharedStoryState)
    func markAlbumOpened()
}

@MainActor
@Observable
final class StoryProgressionSystem: StoryProgressionManaging {
    private(set) var state: SharedStoryState
    private let catalog: [StoryObjectiveDefinition]

    init(state: SharedStoryState? = nil, catalog: [StoryObjectiveDefinition]? = nil) {
        let catalog = catalog ?? StoryContent.objectives
        self.catalog = catalog
        self.state = Self.normalized(state ?? .initial, catalog: catalog)
    }

    var objectives: [StoryObjective] {
        catalog.map { StoryObjective(definition: $0, status: status(for: $0)) }
    }

    var activeObjective: StoryObjective? {
        objectives.first { $0.status == .available || $0.status == .active }
    }

    func definition(id: String) -> StoryObjectiveDefinition? {
        catalog.first { $0.id == id }
    }

    // MARK: - Easel Management

    /// Returns the current drawing prompt for an easel objective.
    /// If labels haven't been selected yet, randomly picks from the pool.
    func currentEaselPrompt(for objectiveID: String) -> DrawingPrompt? {
        guard let objective = definition(id: objectiveID),
              case let .easel(easelDef) = objective.kind else { return nil }

        let selectedLabels = ensureEaselLabelsSelected(for: objectiveID, easel: easelDef)
        let completedLabels = state.easelCompletedLabels[objectiveID] ?? []
        let remaining = selectedLabels.filter { !completedLabels.contains($0) }
        guard let nextLabel = remaining.first else { return nil }
        return easelDef.pool.first { $0.expectedLabel == nextLabel }
            ?? DrawingPrompt(expectedLabel: nextLabel, displayName: nextLabel.uppercased())
    }

    /// Returns count of completed drawings for an easel.
    func easelCompletedCount(for objectiveID: String) -> Int {
        state.easelCompletedLabels[objectiveID]?.count ?? 0
    }

    /// Completes a single drawing within an easel objective.
    func completeEaselDrawing(id: String, label: String) -> [StoryEffect] {
        guard let objective = definition(id: id),
              case let .easel(easelDef) = objective.kind else { return [] }

        let objectiveStatus = status(for: objective)
        guard objectiveStatus == .available || objectiveStatus == .active else { return [] }

        // Record the completed label
        var completedLabels = state.easelCompletedLabels[id] ?? []
        guard !completedLabels.contains(label) else { return [] }
        completedLabels.append(label)
        state.easelCompletedLabels[id] = completedLabels

        // Apply per-drawing reward
        state.intelligence = (state.intelligence + easelDef.perDrawingReward.intelligence).clamped(to: 0...100)
        let engineMaximum = state.hasAdvancedTools ? 100.0 : 60.0
        state.engineProgress = (state.engineProgress + easelDef.perDrawingReward.engine).clamped(to: 0...engineMaximum)

        var effects: [StoryEffect] = [.mapNeedsRefresh]

        // Check if easel is fully complete
        if completedLabels.count >= easelDef.count {
            effects += completeObjective(id: id)
        } else {
            effects += advanceStoryIfPossible()
        }

        return effects
    }

    /// Marks a kitchen label as completed so it won't be selected again.
    func markKitchenLabelCompleted(_ label: String) {
        if !state.kitchenCompletedLabels.contains(label) {
            state.kitchenCompletedLabels.append(label)
        }
    }

    // MARK: - Chapter Access

    func canEnter(_ chapter: StoryChapter) -> Bool {
        switch chapter {
        case .sleepingRoom:
            true
        case .laboratory:
            state.completedObjectiveIDs.contains("reach-laboratory")
        case .enginePhaseOne:
            containsAll(StoryContent.labIDs)
        case .engineBlocked:
            state.engineProgress >= 60
        case .storage:
            state.engineProgress >= 60
        case .engineFinal:
            state.hasAdvancedTools
        case .cockpit:
            state.isCockpitUnlocked
        case .completed:
            containsAll(StoryContent.cockpitIDs)
        }
    }

    func canAccess(_ room: RoomID) -> Bool {
        guard let rule = StoryContent.roomRules.first(where: { $0.roomID == room }) else { return false }
        return rule.allows(state)
    }

    // MARK: - Event Handling

    func handle(_ event: StoryEvent) -> [StoryEffect] {
        switch event {
        case let .roomEntered(room):
            return handleRoomEntry(room)

        case let .stationInteractionRequested(stationID):
            guard let objective = definition(id: stationID) else {
                return [.interactionDenied("Unknown repair station.")]
            }
            let objectiveStatus = status(for: objective)
            guard objectiveStatus == .available || objectiveStatus == .active else {
                let message = objectiveStatus == .blocked
                    ? "Advanced tools are required for this repair."
                    : "This repair is not available yet."
                return [.interactionDenied(message)]
            }
            return []

        case let .drawingValidated(objectiveID, result):
            guard let objective = definition(id: objectiveID) else {
                return [.interactionDenied("This objective does not accept a drawing.")]
            }

            switch objective.kind {
            case let .drawing(prompt):
                guard Self.normalizeLabel(result.label) == Self.normalizeLabel(prompt.expectedLabel) else {
                    return [.interactionDenied("Drawing not recognized. Try again.")]
                }
                return completeObjective(id: objectiveID)

            case .easel:
                guard let currentPrompt = currentEaselPrompt(for: objectiveID) else {
                    return [.interactionDenied("This easel has no more drawings.")]
                }
                guard Self.normalizeLabel(result.label) == Self.normalizeLabel(currentPrompt.expectedLabel) else {
                    return [.interactionDenied("Drawing not recognized. Try again.")]
                }
                return completeEaselDrawing(id: objectiveID, label: currentPrompt.expectedLabel)

            default:
                return [.interactionDenied("This objective does not accept a drawing.")]
            }

        case .energyDepleted:
            return [.gameOver]

        case .foodCompleted, .checkpointRetryRequested:
            return []

        case .newSession:
            state = .initial
            return [
                .chapterChanged(.sleepingRoom),
                .powerChanged(.emergency),
                .checkpointReached(.sleepingRoom),
                .doorAccessChanged(.engine, isUnlocked: false),
                .doorAccessChanged(.storage, isUnlocked: false),
                .doorAccessChanged(.cockpit, isUnlocked: false),
                .mapNeedsRefresh,
                .dialogue(.chapterEntered(.sleepingRoom))
            ]
        }
    }

    func completeObjective(id: String) -> [StoryEffect] {
        guard let objective = definition(id: id),
              !state.completedObjectiveIDs.contains(id) else { return [] }

        let objectiveStatus = status(for: objective)
        guard objectiveStatus == .available || objectiveStatus == .active else { return [] }

        state.completedObjectiveIDs.insert(id)
        state.intelligence = (state.intelligence + objective.reward.intelligence).clamped(to: 0...100)
        let engineMaximum = state.hasAdvancedTools ? 100.0 : 60.0
        state.engineProgress = (state.engineProgress + objective.reward.engine).clamped(to: 0...engineMaximum)

        var effects: [StoryEffect] = [
            .objectiveCompleted(id),
            .stationVisualChanged(id, .completed),
            .dialogue(.objectiveCompleted(id)),
            .mapNeedsRefresh
        ]
        effects.append(contentsOf: advanceStoryIfPossible())
        return effects
    }

    func advanceStoryIfPossible() -> [StoryEffect] {
        var effects: [StoryEffect] = []

        switch state.currentChapter {
        case .sleepingRoom:
            if state.completedObjectiveIDs.contains("reach-laboratory") {
                effects += transition(to: .laboratory, checkpoint: .laboratory)
            }

        case .laboratory:
            if containsAll(StoryContent.labIDs) {
                state.intelligence = max(state.intelligence, 40)
                effects += transition(to: .enginePhaseOne, checkpoint: .laboratory)
                effects += [.doorAccessChanged(.engine, isUnlocked: true)]
            }

        case .enginePhaseOne:
            // Milestone: engine 10 → basicPower
            if state.engineProgress >= 10, state.powerState == .emergency {
                effects += changePower(to: .basicPower)
                effects += setCheckpoint(.enginePhaseOne)
            }
            // Milestone: engine 40 → disruption
            if state.engineProgress >= 40, state.powerState != .disrupted {
                effects += changePower(to: .disrupted)
                effects += [.cutscene(.electricalDisruption)]
                effects += setCheckpoint(.engineDisruption)
            }
            // Easel 1 complete: engine 60 → storage opens
            if containsAll(StoryContent.engineEaselOneIDs) {
                state.engineProgress = max(state.engineProgress, 60)
                state.intelligence = max(state.intelligence, 60)
                effects += transition(to: .engineBlocked, checkpoint: .engineBlocked)
                effects += [.doorAccessChanged(.storage, isUnlocked: true)]
            }

        case .storage:
            if containsAll(StoryContent.storageIDs) {
                state.hasAdvancedTools = true
                effects += transition(to: .engineFinal, checkpoint: .storage)
            }

        case .engineFinal:
            if containsAll(StoryContent.engineFinalIDs) {
                state.engineProgress = 100
                state.intelligence = 100
                effects += changePower(to: .fullyRestored)
                effects += [.cutscene(.engineRestoration)]
                effects += transition(to: .cockpit, checkpoint: .engineFinal)
                effects += [.doorAccessChanged(.cockpit, isUnlocked: true)]
            }

        case .cockpit:
            if containsAll(StoryContent.cockpitIDs) {
                effects += transition(to: .completed, checkpoint: .cockpit)
                effects += [.dialogue(.victory), .victory]
            }

        case .engineBlocked, .completed:
            break
        }

        return effects
    }

    func restore(_ state: SharedStoryState) {
        self.state = Self.normalized(state, catalog: catalog)
    }

    func markDialogueDelivered(id: String) {
        state.deliveredDialogueIDs.insert(id)
    }

    func markAlbumOpened() {
        state.hasOpenedAlbum = true
    }

    func markCommandProcessed(id: UUID) -> Bool {
        state.processedCommandIDs.insert(id).inserted
    }

    private func ensureEaselLabelsSelected(for objectiveID: String, easel: EaselDefinition) -> [String] {
        if let existing = state.easelSelectedLabels[objectiveID] {
            return existing
        }
        let allLabels = easel.pool.map(\.expectedLabel)
        let selected = Array(allLabels.shuffled().prefix(easel.count))
        state.easelSelectedLabels[objectiveID] = selected
        return selected
    }

    private func handleRoomEntry(_ room: RoomID) -> [StoryEffect] {
        guard canAccess(room) else {
            return [.dialogue(.roomDenied(room)), .interactionDenied("Access denied.")]
        }

        if room == .laboratory, state.currentChapter == .sleepingRoom {
            return completeObjective(id: "reach-laboratory")
        }

        if room == .storage, state.currentChapter == .engineBlocked {
            return transition(to: .storage, checkpoint: .engineBlocked)
        }

        if room == .cockpit, state.currentChapter == .cockpit, state.latestCheckpoint != .cockpit {
            return setCheckpoint(.cockpit)
        }

        return []
    }

    private func status(for objective: StoryObjectiveDefinition) -> ObjectiveStatus {
        if state.completedObjectiveIDs.contains(objective.id) { return .completed }

        if objective.chapter == .engineFinal && !state.hasAdvancedTools && state.currentChapter == .engineBlocked {
            return .blocked
        }

        guard objective.chapter == state.currentChapter else { return .locked }
        guard objective.requiredObjectiveIDs.allSatisfy(state.completedObjectiveIDs.contains) else { return .locked }
        return .available
    }

    private func transition(to chapter: StoryChapter, checkpoint: CheckpointID) -> [StoryEffect] {
        guard state.currentChapter != chapter else { return [] }
        state.currentChapter = chapter
        var effects: [StoryEffect] = [
            .chapterChanged(chapter),
            .dialogue(.chapterEntered(chapter)),
            .mapNeedsRefresh
        ]
        effects += setCheckpoint(checkpoint)
        return effects
    }

    private func changePower(to power: ShipPowerState) -> [StoryEffect] {
        guard state.powerState != power else { return [] }
        state.powerState = power
        return [.powerChanged(power), .dialogue(.powerChanged(power)), .mapNeedsRefresh]
    }

    private func setCheckpoint(_ checkpoint: CheckpointID) -> [StoryEffect] {
        guard state.latestCheckpoint != checkpoint else { return [] }
        state.latestCheckpoint = checkpoint
        return [.checkpointReached(checkpoint)]
    }

    private func containsAll(_ ids: [String]) -> Bool {
        ids.allSatisfy(state.completedObjectiveIDs.contains)
    }

    // MARK: - State Normalization

    private static func normalized(_ input: SharedStoryState, catalog: [StoryObjectiveDefinition]) -> SharedStoryState {
        var state = input
        let knownIDs = Set(catalog.map(\.id))
        state.completedObjectiveIDs.formIntersection(knownIDs)
        state.intelligence = state.intelligence.clamped(to: 10...100)

        let hasAll: ([String]) -> Bool = { ids in
            ids.allSatisfy(state.completedObjectiveIDs.contains)
        }
        if hasAll(StoryContent.labIDs) { state.intelligence = max(state.intelligence, 40) }
        if hasAll(StoryContent.engineEaselOneIDs) {
            state.engineProgress = max(state.engineProgress, 60)
            state.intelligence = max(state.intelligence, 60)
        }
        if hasAll(StoryContent.storageIDs) { state.hasAdvancedTools = true }
        if hasAll(StoryContent.engineFinalIDs) {
            state.engineProgress = 100
            state.intelligence = 100
        }

        let engineMaximum = state.hasAdvancedTools ? 100.0 : 60.0
        state.engineProgress = state.engineProgress.clamped(to: 0...engineMaximum)

        if !hasAll(StoryContent.labIDs) {
            state.powerState = .emergency
        } else if hasAll(StoryContent.engineFinalIDs) {
            state.powerState = .fullyRestored
        } else if state.engineProgress >= 40 {
            state.powerState = .disrupted
        } else if state.engineProgress >= 10 {
            state.powerState = .basicPower
        } else {
            state.powerState = .emergency
        }

        let restoredChapter = state.currentChapter
        if hasAll(StoryContent.cockpitIDs) {
            state.currentChapter = .completed
        } else if hasAll(StoryContent.engineFinalIDs) {
            state.currentChapter = .cockpit
        } else if state.hasAdvancedTools {
            state.currentChapter = .engineFinal
        } else if hasAll(StoryContent.engineEaselOneIDs) {
            state.currentChapter = restoredChapter == .storage ? .storage : .engineBlocked
        } else if hasAll(StoryContent.labIDs) {
            state.currentChapter = .enginePhaseOne
        } else if state.completedObjectiveIDs.contains("reach-laboratory") {
            state.currentChapter = .laboratory
        } else {
            state.currentChapter = .sleepingRoom
        }

        state.latestCheckpoint = normalizedCheckpoint(
            state.latestCheckpoint,
            chapter: state.currentChapter,
            hasDisruption: state.engineProgress >= 40
        )
        return state
    }

    private static func normalizedCheckpoint(
        _ checkpoint: CheckpointID,
        chapter: StoryChapter,
        hasDisruption: Bool
    ) -> CheckpointID {
        switch chapter {
        case .sleepingRoom: .sleepingRoom
        case .laboratory: .laboratory
        case .enginePhaseOne: hasDisruption ? .engineDisruption : .enginePhaseOne
        case .engineBlocked, .storage: .engineBlocked
        case .engineFinal: .storage
        case .cockpit: checkpoint == .cockpit ? .cockpit : .engineFinal
        case .completed: .cockpit
        }
    }

    private static func normalizeLabel(_ label: String) -> String {
        label.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
