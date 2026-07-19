import Testing
@testable import GameClassification

@Suite("Story progression")
@MainActor
struct StoryProgressionSystemTests {
    @Test("Story configuration uses the exact authored 19-station order")
    func physicalStationOrder() {
        #expect(StoryConfiguration.challenges.map(\.id) == [
            "lab-memory-repair", "lab-scanner-repair", "lab-terminal-repair",
            "engine-ignition-coil", "engine-power-connector", "engine-control-relay",
            "engine-cooling-valve", "engine-cooling-restart", "engine-reactor-link",
            "storage-tool-terminal", "storage-robotic-arm", "storage-calibration-unit",
            "engine-calibration-port", "engine-core-reconnect", "engine-propulsion-calibration",
            "engine-reactor-stabilizer", "cockpit-communications", "cockpit-navigation-control",
            "cockpit-flight-console"
        ])
        #expect(StoryConfiguration.laboratoryChallenges.map(\.category) == [.animal, .plant, .human])
        #expect(StoryConfiguration.storageChallenges.map(\.category) == [.tool, .equipment, .furniture])
        #expect(StoryConfiguration.engineFinalChallenges.map(\.category) == [.electronics, .electronics, .weapon, .electronics])
        #expect(StoryConfiguration.cockpitChallenges.allSatisfy { $0.category == .celestial })
    }

    @Test("Initial state exposes the exact travel mission")
    func initialState() {
        let system = StoryProgressionSystem()

        #expect(system.state.currentChapter == .sleepingRoom)
        #expect(system.state.intelligence == 10)
        #expect(system.state.engineProgress == 0)
        #expect(system.state.powerState == .off)
        #expect(system.state.activeMission?.title == "Find the Laboratory.")
        #expect(system.activeObjective == nil)
        #expect(system.canAccess(.laboratory))
        #expect(!system.canAccess(.engine))
    }

    @Test("All 19 physical stations produce the fixed progression and Victory")
    func completeStory() throws {
        let system = StoryProgressionSystem()
        _ = system.handle(.roomEntered(.laboratory))

        #expect(system.state.latestCheckpoint == .laboratoryEntered)
        #expect(system.state.activeMission?.title == "Restore the AI.")
        completeChapter(.laboratory, in: system)
        #expect(system.state.intelligence == 40)
        #expect(system.state.engineProgress == 0)
        #expect(system.state.currentChapter == .engineInitial)
        #expect(system.state.activeMission?.title == "Repair the Engine.")

        for (index, definition) in StoryConfiguration.engineInitialChallenges.enumerated() {
            let effects = validate(definition.id, in: system)
            #expect(system.state.engineProgress == Double((index + 1) * 10))
            #expect(system.state.intelligence == 40)
            if index == 0 { #expect(effects.contains(.powerChanged(.basicPower))) }
            if index == 3 { #expect(effects.contains(.powerChanged(.disrupted))) }
        }
        #expect(system.state.currentChapter == .storage)
        #expect(system.state.engineProgress == 60)
        #expect(system.state.activeMission?.title == "Retrieve the calibration tools from Storage.")

        completeChapter(.storage, in: system)
        #expect(system.state.hasAdvancedRepairTools)
        #expect(system.state.currentChapter == .engineFinal)
        #expect(system.state.activeMission?.title == "Continue repairing the Engine.")

        for (index, definition) in StoryConfiguration.engineFinalChallenges.enumerated() {
            _ = validate(definition.id, in: system)
            #expect(system.state.engineProgress == Double(70 + index * 10))
            #expect(system.state.intelligence == Double(55 + index * 15))
        }
        #expect(system.state.powerState == .fullyRestored)
        #expect(system.state.currentChapter == .cockpit)
        #expect(system.canAccess(.cockpit))
        #expect(system.state.activeMission?.title == "Go to the Cockpit and initiate launch.")

        let cockpitLabels = StoryConfiguration.cockpitChallenges.compactMap {
            system.state.selectedChallengeLabels[$0.id]
        }
        #expect(Set(cockpitLabels) == Set(["moon", "sun", "ufo"]))

        _ = system.handle(.roomEntered(.cockpit))
        for (index, definition) in StoryConfiguration.cockpitChallenges.enumerated() {
            let effects = validate(definition.id, in: system)
            if index < 2 {
                #expect(system.state.currentChapter == .cockpit)
            } else {
                #expect(system.state.currentChapter == .victory)
                #expect(effects.contains(.victory))
            }
        }
        #expect(system.state.completedChallengeIDs.count == 19)
        #expect(system.state.completedMissionIDs.count == 6)
    }

    @Test("Wrong and low-confidence recognition fail once without progress or repeated hints")
    func recognitionValidationAndAlbumHint() throws {
        let system = StoryProgressionSystem()
        _ = system.handle(.roomEntered(.laboratory))
        let id = try #require(system.activeObjective?.id)
        let prompt = try #require(system.currentPrompt(for: id))

        let wrong = system.handle(.drawingValidated(
            objectiveID: id,
            result: RecognitionResult(label: "invalid-label", confidence: 1, alternatives: [])
        ))
        let uncertain = system.handle(.drawingValidated(
            objectiveID: id,
            result: RecognitionResult(label: prompt.expectedLabel, confidence: 0.49, alternatives: [])
        ))

        #expect(wrong.contains(.dialogue(.albumHint)))
        #expect(!uncertain.contains(.dialogue(.albumHint)))
        #expect(system.state.albumBook.hasFailedDrawingBefore)
        #expect(system.state.albumBook.hasReceivedHint)
        #expect(system.state.albumBook.isMarkerVisible)
        #expect(system.state.intelligence == 10)
        #expect(system.state.completedChallengeIDs.isEmpty)
    }

    @Test("Challenge and milestone rewards are idempotent")
    func idempotency() throws {
        let system = StoryProgressionSystem()
        _ = system.handle(.roomEntered(.laboratory))
        let id = try #require(system.activeObjective?.id)
        let prompt = try #require(system.currentPrompt(for: id))
        let result = RecognitionResult(label: prompt.expectedLabel, confidence: 1, alternatives: [])

        let first = system.handle(.drawingValidated(objectiveID: id, result: result))
        let duplicate = system.handle(.drawingValidated(objectiveID: id, result: result))

        #expect(first.contains(.objectiveCompleted(id)))
        #expect(duplicate.contains { if case .interactionDenied = $0 { true } else { false } })
        #expect(system.state.intelligence == 20)
        #expect(system.state.completedChallengeIDs.filter { $0 == id }.count == 1)
    }

    @Test("Chapter labels are stable, unique, category-valid, and persisted")
    func deterministicLabels() {
        var initial = StoryState.initial
        initial.storyRandomSeed = 8_675_309
        initial.currentChapter = .laboratory
        let first = StoryProgressionSystem(state: initial)
        let restored = StoryProgressionSystem(state: first.state)

        #expect(first.state.selectedChallengeLabels == restored.state.selectedChallengeLabels)
        #expect(first.state.chapterChallengeSelections == restored.state.chapterChallengeSelections)
        let selections = first.state.chapterChallengeSelections[.laboratory] ?? []
        #expect(Set(selections.map(\.label)).count == selections.count)
        #expect(selections.allSatisfy { first.labelCatalog.contains($0.label, in: $0.category) })
        for (definition, selection) in zip(StoryConfiguration.laboratoryChallenges, selections) {
            #expect(first.state.selectedChallengeLabels[definition.id] == selection.label)
        }
    }

    @Test("Malformed final repairs cannot push Engine beyond 60 without Storage tools")
    func hardEngineCapWithoutTools() {
        var state = StoryState.initial
        state.currentChapter = .engineFinal
        state.completedChallengeIDs = Set(
            StoryConfiguration.laboratoryChallenges.map(\.id)
                + StoryConfiguration.engineInitialChallenges.map(\.id)
                + StoryConfiguration.engineFinalChallenges.map(\.id)
        )

        let system = StoryProgressionSystem(state: state)

        #expect(system.state.engineProgress == 60)
        #expect(system.state.intelligence == 40)
        #expect(system.state.currentChapter == .storage)
        #expect(!system.state.hasAdvancedRepairTools)
        #expect(!system.canAccess(.cockpit))
    }

    @Test("Malformed values cannot bypass the Cockpit gate")
    func restoreNormalization() {
        var malformed = StoryState.initial
        malformed.currentChapter = .cockpit
        malformed.completedChallengeIDs = ["unknown-objective"]
        malformed.intelligence = 900
        malformed.engineProgress = 900
        malformed.powerState = .fullyRestored

        let system = StoryProgressionSystem(state: malformed)

        #expect(system.state.intelligence == 10)
        #expect(system.state.engineProgress == 0)
        #expect(system.state.currentChapter == .laboratory)
        #expect(system.state.powerState == .off)
        #expect(system.state.completedChallengeIDs.isEmpty)
        #expect(!system.canAccess(.cockpit))
    }

    private func completeChapter(_ chapter: StoryChapter, in system: StoryProgressionSystem) {
        for definition in StoryConfiguration.challenges(for: chapter) {
            _ = validate(definition.id, in: system)
        }
    }

    @discardableResult
    private func validate(_ id: String, in system: StoryProgressionSystem) -> [StoryEffect] {
        guard let prompt = system.currentPrompt(for: id) else {
            Issue.record("Missing prompt for \(id)")
            return []
        }
        return system.handle(.drawingValidated(
            objectiveID: id,
            result: RecognitionResult(label: prompt.expectedLabel, confidence: 1, alternatives: [])
        ))
    }
}
