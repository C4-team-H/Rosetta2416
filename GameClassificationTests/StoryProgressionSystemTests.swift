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

        complete(StoryContent.enginePhaseOneIDs, in: system)
        #expect(system.state.engineProgress == 10)
        #expect(system.state.powerState == .basicPower)
        #expect(system.state.currentChapter == .enginePhaseTwo)

        complete(StoryContent.enginePhaseTwoDisruptionIDs, in: system)
        #expect(system.state.engineProgress == 40)
        #expect(system.state.intelligence == 50)
        #expect(system.state.powerState == .disrupted)

        complete(Array(StoryContent.enginePhaseTwoIDs.suffix(2)), in: system)
        #expect(system.state.engineProgress == 60)
        #expect(system.state.intelligence == 60)
        #expect(system.state.currentChapter == .engineBlocked)
        #expect(system.canAccess(.storage))

        let blockedEffects = validate("engine-reactor-stabilizer", in: system)
        #expect(blockedEffects.isEmpty)
        #expect(system.state.engineProgress == 60)

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

        complete(Array(StoryContent.cockpitIDs.prefix(2)), in: system)
        #expect(system.state.currentChapter == .cockpit)
        let victoryEffects = validate(StoryContent.cockpitIDs[2], in: system)
        #expect(system.state.currentChapter == .completed)
        #expect(victoryEffects.contains(.victory))
    }

    @Test("Duplicate completions and invalid order never grant rewards twice")
    func idempotencyAndOrder() {
        let system = StoryProgressionSystem()

        #expect(validate("engine-power-connector", in: system).isEmpty)
        _ = system.handle(.roomEntered(.laboratory))
        let first = validate("lab-terminal-repair", in: system)
        let intelligence = system.state.intelligence
        let duplicate = validate("lab-terminal-repair", in: system)

        #expect(first.contains(.objectiveCompleted("lab-terminal-repair")))
        #expect(duplicate.isEmpty)
        #expect(system.state.intelligence == intelligence)
    }

    @Test("Low confidence and wrong labels remain retryable")
    func recognitionValidation() {
        let system = StoryProgressionSystem()
        _ = system.handle(.roomEntered(.laboratory))

        let wrong = system.handle(.drawingValidated(
            objectiveID: "lab-terminal-repair",
            result: RecognitionResult(label: "brain", confidence: 0.99, alternatives: [])
        ))
        let uncertain = system.handle(.drawingValidated(
            objectiveID: "lab-terminal-repair",
            result: RecognitionResult(label: "radio", confidence: 0.49, alternatives: [])
        ))

        #expect(!wrong.isEmpty)
        #expect(!uncertain.isEmpty)
        #expect(!system.state.completedObjectiveIDs.contains("lab-terminal-repair"))
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
            ["reach-laboratory"] + StoryContent.labIDs + StoryContent.enginePhaseOneIDs
                + StoryContent.enginePhaseTwoIDs + StoryContent.storageIDs
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
        guard let definition = system.definition(id: id),
              case let .drawing(prompt) = definition.kind else {
            return system.completeObjective(id: id)
        }
        return system.handle(.drawingValidated(
            objectiveID: id,
            result: RecognitionResult(label: prompt.expectedLabel, confidence: 1, alternatives: [])
        ))
    }
}
