import CoreGraphics
import Testing
@testable import GameClassification

@Suite("Story progression")
@MainActor
struct StoryProgressionSystemTests {
    @Test("Initial session starts safely in the Sleeping Room")
    func initialState() {
        let system = StoryProgressionSystem()

        #expect(system.state.currentChapter == .sleepingRoom)
        #expect(system.state.intelligence == 10)
        #expect(system.state.engineProgress == 0)
        #expect(system.state.powerState == .emergency)
        #expect(system.activeObjective?.id == "reach-laboratory")
        #expect(system.canAccess(.laboratory))
        #expect(!system.canAccess(.engine))
    }

    @Test("The complete deterministic story reaches victory only after Cockpit repairs")
    func completeStory() {
        let system = StoryProgressionSystem()

        _ = system.handle(.roomEntered(.laboratory))
        #expect(system.state.currentChapter == .laboratory)

        complete(StoryContent.labIDs, in: system)
        #expect(system.state.intelligence == 40)
        #expect(system.state.currentChapter == .enginePhaseOne)
        #expect(system.canAccess(.engine))

        // Step drawings on engine-easel-1 one by one to verify power changes
        let easelID = "engine-easel-1"
        guard let objective = system.definition(id: easelID),
              case .easel(_) = objective.kind else {
            Issue.record("engine-easel-1 must be an easel")
            return
        }

        // Drawing 1
        if let prompt = system.currentEaselPrompt(for: easelID) {
            _ = system.handle(.drawingValidated(objectiveID: easelID, result: RecognitionResult(label: prompt.expectedLabel, confidence: 1.0, alternatives: [])))
        }
        #expect(system.state.engineProgress == 10)
        #expect(system.state.powerState == .basicPower)

        // Drawings 2, 3, 4
        for _ in 0..<3 {
            if let prompt = system.currentEaselPrompt(for: easelID) {
                _ = system.handle(.drawingValidated(objectiveID: easelID, result: RecognitionResult(label: prompt.expectedLabel, confidence: 1.0, alternatives: [])))
            }
        }
        #expect(system.state.engineProgress == 40)
        #expect(system.state.powerState == .disrupted)

        // Drawings 5, 6
        for _ in 0..<2 {
            if let prompt = system.currentEaselPrompt(for: easelID) {
                _ = system.handle(.drawingValidated(objectiveID: easelID, result: RecognitionResult(label: prompt.expectedLabel, confidence: 1.0, alternatives: [])))
            }
        }
        #expect(system.state.engineProgress == 60)
        #expect(system.state.intelligence == 60)
        #expect(system.state.currentChapter == .engineBlocked)
        #expect(system.canAccess(.storage))

        _ = system.handle(.roomEntered(.storage))
        #expect(system.state.currentChapter == .storage)
        complete(StoryContent.storageIDs, in: system)
        #expect(system.state.hasAdvancedTools)
        #expect(system.state.currentChapter == .engineFinal)

        complete(StoryContent.engineFinalIDs, in: system)
        #expect(system.state.engineProgress == 100)
        #expect(system.state.intelligence == 100)
        #expect(system.state.powerState == .fullyRestored)
        #expect(system.state.currentChapter == .cockpit)
        #expect(system.canAccess(.cockpit))

        _ = system.handle(.roomEntered(.cockpit))
        #expect(system.state.currentChapter == .cockpit)

        let cockpitEaselID = "cockpit-easel"
        guard let cockpitDef = system.definition(id: cockpitEaselID),
              case let .easel(cockpitEaselDef) = cockpitDef.kind else {
            Issue.record("cockpit-easel must be an easel")
            return
        }
        for i in 0..<cockpitEaselDef.count {
            guard let prompt = system.currentEaselPrompt(for: cockpitEaselID) else { break }
            let effects = system.handle(.drawingValidated(
                objectiveID: cockpitEaselID,
                result: RecognitionResult(label: prompt.expectedLabel, confidence: 1.0, alternatives: [])
            ))
            if i < cockpitEaselDef.count - 1 {
                #expect(system.state.currentChapter == .cockpit)
            } else {
                #expect(system.state.currentChapter == .completed)
                #expect(effects.contains(.victory))
            }
        }
    }

    @Test("Duplicate completions and invalid order never grant rewards twice")
    func idempotencyAndOrder() {
        let system = StoryProgressionSystem()

        #expect(validate("engine-easel-1", in: system).isEmpty)
        _ = system.handle(.roomEntered(.laboratory))
        
        guard let prompt = system.currentEaselPrompt(for: "lab-easel") else {
            Issue.record("Must have current prompt for lab-easel")
            return
        }
        let first = system.handle(.drawingValidated(
            objectiveID: "lab-easel",
            result: RecognitionResult(label: prompt.expectedLabel, confidence: 1.0, alternatives: [])
        ))
        let intelligence = system.state.intelligence
        let duplicate = system.handle(.drawingValidated(
            objectiveID: "lab-easel",
            result: RecognitionResult(label: prompt.expectedLabel, confidence: 1.0, alternatives: [])
        ))

        #expect(first.contains(.mapNeedsRefresh))
        #expect(duplicate.contains { if case .interactionDenied = $0 { return true }; return false })
        #expect(system.state.intelligence == intelligence)
    }

    @Test("Low confidence and wrong labels remain retryable")
    func recognitionValidation() {
        let system = StoryProgressionSystem()
        _ = system.handle(.roomEntered(.laboratory))

        guard let prompt = system.currentEaselPrompt(for: "lab-easel") else {
            Issue.record("No prompt")
            return
        }
        let wrong = system.handle(.drawingValidated(
            objectiveID: "lab-easel",
            result: RecognitionResult(label: "invalid-label", confidence: 0.99, alternatives: [])
        ))
        let uncertain = system.handle(.drawingValidated(
            objectiveID: "lab-easel",
            result: RecognitionResult(label: prompt.expectedLabel, confidence: 0.49, alternatives: [])
        ))

        #expect(wrong.contains { if case .interactionDenied = $0 { return true }; return false })
        #expect(uncertain.contains { if case .interactionDenied = $0 { return true }; return false })
        #expect(system.easelCompletedCount(for: "lab-easel") == 0)
    }

    @Test("Restored values and unknown IDs normalize without bypassing gates")
    func restoreNormalization() {
        var malformed = SharedStoryState.initial
        malformed.currentChapter = .cockpit
        malformed.completedObjectiveIDs = ["unknown-objective"]
        malformed.intelligence = 900
        malformed.engineProgress = 900
        malformed.powerState = .fullyRestored

        let system = StoryProgressionSystem(state: malformed)

        #expect(system.state.intelligence == 100)
        #expect(system.state.engineProgress == 60)
        #expect(system.state.currentChapter == .sleepingRoom)
        #expect(system.state.powerState == .emergency)
        #expect(system.state.completedObjectiveIDs.isEmpty)
        #expect(!system.canAccess(.cockpit))
    }

    @Test("Cockpit requires both Engine and Intelligence at 100")
    func cockpitThresholds() {
        var lowIntelligence = SharedStoryState.initial
        lowIntelligence.currentChapter = .engineFinal
        lowIntelligence.completedObjectiveIDs = Set(
            ["reach-laboratory"] + StoryContent.labIDs + StoryContent.engineEaselOneIDs + StoryContent.storageIDs
        )
        lowIntelligence.hasAdvancedTools = true
        lowIntelligence.engineProgress = 100
        lowIntelligence.intelligence = 99

        var lowEngine = lowIntelligence
        lowEngine.engineProgress = 99
        lowEngine.intelligence = 100

        let intelligenceGate = StoryProgressionSystem(state: lowIntelligence)
        let engineGate = StoryProgressionSystem(state: lowEngine)

        #expect(!intelligenceGate.canAccess(.cockpit))
        #expect(!engineGate.canAccess(.cockpit))
    }

    private func complete(_ ids: [String], in system: StoryProgressionSystem) {
        for id in ids { _ = validate(id, in: system) }
    }

    @discardableResult
    private func validate(_ id: String, in system: StoryProgressionSystem) -> [StoryEffect] {
        guard let definition = system.definition(id: id) else { return [] }
        switch definition.kind {
        case let .drawing(prompt):
            return system.handle(.drawingValidated(
                objectiveID: id,
                result: RecognitionResult(label: prompt.expectedLabel, confidence: 1.0, alternatives: [])
            ))
        case let .easel(easelDef):
            var lastEffects: [StoryEffect] = []
            for _ in 0..<easelDef.count {
                guard let prompt = system.currentEaselPrompt(for: id) else { break }
                lastEffects = system.handle(.drawingValidated(
                    objectiveID: id,
                    result: RecognitionResult(label: prompt.expectedLabel, confidence: 1.0, alternatives: [])
                ))
            }
            return lastEffects
        case .roomEntry:
            return system.completeObjective(id: id)
        default:
            return system.completeObjective(id: id)
        }
    }
}
