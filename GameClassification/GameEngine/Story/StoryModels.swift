import CoreGraphics
import Foundation

enum RoomID: String, Codable, CaseIterable, Sendable {
    case sleepingRoom
    case laboratory
    case engine
    case kitchen
    case storage
    case cockpit

    var displayName: String {
        switch self {
        case .sleepingRoom: "Sleeping Room"
        case .laboratory: "Lab Room"
        case .engine: "Engine Room"
        case .kitchen: "Kitchen"
        case .storage: "Storage Room"
        case .cockpit: "Cockpit"
        }
    }

    var triggerNodeName: String { "room-trigger-\(rawValue)" }
}

enum ObjectiveStatus: String, Codable, Sendable {
    case locked
    case available
    case active
    case completed
    case blocked
}

enum ObjectivePriority: String, Codable, Sendable {
    case main
    case optional
}

enum DialogueTrigger: Codable, Equatable, Sendable {
    case chapterEntered(StoryChapter)
    case objectiveCompleted(String)
    case powerChanged(ShipPowerState)
    case roomDenied(RoomID)
    case energyLow
    case albumHint
    case victory
}

enum StoryCutscene: String, Codable, Equatable, Sendable {
    case electricalDisruption
    case advancedToolsAcquired
    case engineRestoration
}

struct DrawingPrompt: Codable, Equatable, Sendable {
    let expectedLabel: String
    let displayName: String
    let confidenceThreshold: Double

    init(expectedLabel: String, displayName: String, confidenceThreshold: Double = 0.30) {
        self.expectedLabel = expectedLabel
        self.displayName = displayName
        self.confidenceThreshold = confidenceThreshold
    }
}

struct EaselDefinition: Codable, Equatable, Sendable {
    let pool: [DrawingPrompt]
    let count: Int
    let perDrawingReward: StoryProgressReward
}

enum ObjectiveKind: Codable, Equatable, Sendable {
    case roomEntry(RoomID)
    case drawing(DrawingPrompt)
    case easel(EaselDefinition)
    case interaction(String)
    case collection(String)
}

struct StoryProgressReward: Codable, Equatable, Sendable {
    let intelligence: Double
    let engine: Double

    static let none = StoryProgressReward(intelligence: 0, engine: 0)
}

struct StoryObjectiveDefinition: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let chapter: StoryChapter
    let roomID: RoomID
    let title: String
    let description: String
    let requiredObjectiveIDs: [String]
    let reward: StoryProgressReward
    let kind: ObjectiveKind
    let priority: ObjectivePriority
}

struct StoryObjective: Identifiable, Codable, Equatable, Sendable {
    let definition: StoryObjectiveDefinition
    let status: ObjectiveStatus

    var id: String { definition.id }
}

struct StoryState: Codable, Equatable, Sendable {
    var currentChapter: StoryChapter
    var intelligence: Double
    var engineProgress: Double
    var completedChallengeIDs: Set<String>
    var activeMission: MissionState?
    var completedMissionIDs: Set<MissionID>
    var hasAdvancedRepairTools: Bool
    var isEngineRoomUnlocked: Bool
    var isStorageUnlocked: Bool
    var isCockpitUnlocked: Bool
    var powerState: ShipPowerState
    var albumBook: AlbumBookState
    var selectedChallengeLabels: [String: String]
    var chapterChallengeSelections: [StoryChapter: [DrawingChallengeSelection]]
    var storyRandomSeed: UInt64
    var processedMilestoneIDs: Set<String>
    var deliveredDialogueIDs: Set<String>
    var processedCommandIDs: Set<UUID>
    var latestCheckpoint: CheckpointID

    init(
        currentChapter: StoryChapter,
        intelligence: Double,
        engineProgress: Double,
        completedChallengeIDs: Set<String>,
        activeMission: MissionState?,
        completedMissionIDs: Set<MissionID>,
        hasAdvancedRepairTools: Bool,
        isEngineRoomUnlocked: Bool,
        isStorageUnlocked: Bool,
        isCockpitUnlocked: Bool,
        powerState: ShipPowerState,
        albumBook: AlbumBookState,
        selectedChallengeLabels: [String: String],
        chapterChallengeSelections: [StoryChapter: [DrawingChallengeSelection]],
        storyRandomSeed: UInt64,
        processedMilestoneIDs: Set<String>,
        deliveredDialogueIDs: Set<String>,
        processedCommandIDs: Set<UUID>,
        latestCheckpoint: CheckpointID
    ) {
        self.currentChapter = currentChapter
        self.intelligence = intelligence
        self.engineProgress = engineProgress
        self.completedChallengeIDs = completedChallengeIDs
        self.activeMission = activeMission
        self.completedMissionIDs = completedMissionIDs
        self.hasAdvancedRepairTools = hasAdvancedRepairTools
        self.isEngineRoomUnlocked = isEngineRoomUnlocked
        self.isStorageUnlocked = isStorageUnlocked
        self.isCockpitUnlocked = isCockpitUnlocked
        self.powerState = powerState
        self.albumBook = albumBook
        self.selectedChallengeLabels = selectedChallengeLabels
        self.chapterChallengeSelections = chapterChallengeSelections
        self.storyRandomSeed = storyRandomSeed
        self.processedMilestoneIDs = processedMilestoneIDs
        self.deliveredDialogueIDs = deliveredDialogueIDs
        self.processedCommandIDs = processedCommandIDs
        self.latestCheckpoint = latestCheckpoint
    }

    static var initial: StoryState {
        var generator = SystemRandomNumberGenerator()
        return StoryState(
            currentChapter: .sleepingRoom,
            intelligence: 10,
            engineProgress: 0,
            completedChallengeIDs: [],
            activeMission: StoryConfiguration.mission(for: .sleepingRoom),
            completedMissionIDs: [],
            hasAdvancedRepairTools: false,
            isEngineRoomUnlocked: false,
            isStorageUnlocked: false,
            isCockpitUnlocked: false,
            powerState: .off,
            albumBook: AlbumBookState(),
            selectedChallengeLabels: [:],
            chapterChallengeSelections: [:],
            storyRandomSeed: generator.next(),
            processedMilestoneIDs: [],
            deliveredDialogueIDs: [],
            processedCommandIDs: [],
            latestCheckpoint: .sleepingRoomStart
        )
    }

    private enum CodingKeys: String, CodingKey {
        case currentChapter
        case intelligence
        case engineProgress
        case completedChallengeIDs
        case activeMission
        case completedMissionIDs
        case hasAdvancedRepairTools
        case isEngineRoomUnlocked
        case isStorageUnlocked
        case isCockpitUnlocked
        case powerState
        case albumBook
        case selectedChallengeLabels
        case chapterChallengeSelections
        case storyRandomSeed
        case processedMilestoneIDs
        case deliveredDialogueIDs
        case processedCommandIDs
        case latestCheckpoint

        // Schema v1 keys.
        case completedObjectiveIDs
        case hasAdvancedTools
        case easelSelectedLabels
        case easelCompletedLabels
        case hasOpenedAlbum
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var migrated = StoryState.initial
        migrated.currentChapter = try container.decodeIfPresent(StoryChapter.self, forKey: .currentChapter) ?? .sleepingRoom
        migrated.intelligence = try container.decodeIfPresent(Double.self, forKey: .intelligence) ?? 10
        migrated.engineProgress = try container.decodeIfPresent(Double.self, forKey: .engineProgress) ?? 0
        migrated.completedChallengeIDs = try container.decodeIfPresent(Set<String>.self, forKey: .completedChallengeIDs) ?? []
        migrated.activeMission = try container.decodeIfPresent(MissionState.self, forKey: .activeMission)
        migrated.completedMissionIDs = try container.decodeIfPresent(Set<MissionID>.self, forKey: .completedMissionIDs) ?? []
        migrated.hasAdvancedRepairTools = try container.decodeIfPresent(Bool.self, forKey: .hasAdvancedRepairTools)
            ?? container.decodeIfPresent(Bool.self, forKey: .hasAdvancedTools)
            ?? false
        migrated.isEngineRoomUnlocked = try container.decodeIfPresent(Bool.self, forKey: .isEngineRoomUnlocked) ?? false
        migrated.isStorageUnlocked = try container.decodeIfPresent(Bool.self, forKey: .isStorageUnlocked) ?? false
        migrated.isCockpitUnlocked = try container.decodeIfPresent(Bool.self, forKey: .isCockpitUnlocked) ?? false
        migrated.powerState = try container.decodeIfPresent(ShipPowerState.self, forKey: .powerState) ?? .off
        migrated.albumBook = try container.decodeIfPresent(AlbumBookState.self, forKey: .albumBook) ?? AlbumBookState()
        migrated.selectedChallengeLabels = try container.decodeIfPresent([String: String].self, forKey: .selectedChallengeLabels) ?? [:]
        migrated.chapterChallengeSelections = try container.decodeIfPresent(
            [StoryChapter: [DrawingChallengeSelection]].self,
            forKey: .chapterChallengeSelections
        ) ?? [:]
        migrated.storyRandomSeed = try container.decodeIfPresent(UInt64.self, forKey: .storyRandomSeed)
            ?? migrated.storyRandomSeed
        migrated.processedMilestoneIDs = try container.decodeIfPresent(Set<String>.self, forKey: .processedMilestoneIDs) ?? []
        migrated.deliveredDialogueIDs = try container.decodeIfPresent(Set<String>.self, forKey: .deliveredDialogueIDs) ?? []
        migrated.processedCommandIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .processedCommandIDs) ?? []
        migrated.latestCheckpoint = try container.decodeIfPresent(CheckpointID.self, forKey: .latestCheckpoint) ?? .sleepingRoomStart

        if try container.decodeIfPresent(Bool.self, forKey: .hasOpenedAlbum) == true {
            migrated.albumBook.hasOpenedBook = true
            migrated.albumBook.isMarkerVisible = true
            migrated.albumBook.isMarkerPermanent = true
        }

        let legacyCompletedObjectiveIDs = try container.decodeIfPresent(Set<String>.self, forKey: .completedObjectiveIDs) ?? []
        let legacySelections = try container.decodeIfPresent([String: [String]].self, forKey: .easelSelectedLabels) ?? [:]
        let legacyCompletions = try container.decodeIfPresent([String: [String]].self, forKey: .easelCompletedLabels) ?? [:]
        Self.migrateLegacyEasel(
            id: "lab-easel",
            definitions: StoryConfiguration.laboratoryChallenges,
            completedObjectiveIDs: legacyCompletedObjectiveIDs,
            selections: legacySelections,
            completions: legacyCompletions,
            state: &migrated
        )
        Self.migrateLegacyEasel(
            id: "engine-easel-1",
            definitions: StoryConfiguration.engineInitialChallenges,
            completedObjectiveIDs: legacyCompletedObjectiveIDs,
            selections: legacySelections,
            completions: legacyCompletions,
            state: &migrated
        )
        Self.migrateLegacyEasel(
            id: "storage-easel",
            definitions: StoryConfiguration.storageChallenges,
            completedObjectiveIDs: legacyCompletedObjectiveIDs,
            selections: legacySelections,
            completions: legacyCompletions,
            state: &migrated
        )
        Self.migrateLegacyEasel(
            id: "engine-easel-2",
            definitions: StoryConfiguration.engineFinalChallenges,
            completedObjectiveIDs: legacyCompletedObjectiveIDs,
            selections: legacySelections,
            completions: legacyCompletions,
            state: &migrated
        )
        Self.migrateLegacyEasel(
            id: "cockpit-easel",
            definitions: StoryConfiguration.cockpitChallenges,
            completedObjectiveIDs: legacyCompletedObjectiveIDs,
            selections: legacySelections,
            completions: legacyCompletions,
            state: &migrated
        )
        if legacyCompletedObjectiveIDs.contains("reach-laboratory") {
            migrated.completedMissionIDs.insert(.findLaboratory)
            if migrated.currentChapter == .sleepingRoom { migrated.currentChapter = .laboratory }
        }

        self = migrated
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(currentChapter, forKey: .currentChapter)
        try container.encode(intelligence, forKey: .intelligence)
        try container.encode(engineProgress, forKey: .engineProgress)
        try container.encode(completedChallengeIDs, forKey: .completedChallengeIDs)
        try container.encodeIfPresent(activeMission, forKey: .activeMission)
        try container.encode(completedMissionIDs, forKey: .completedMissionIDs)
        try container.encode(hasAdvancedRepairTools, forKey: .hasAdvancedRepairTools)
        try container.encode(isEngineRoomUnlocked, forKey: .isEngineRoomUnlocked)
        try container.encode(isStorageUnlocked, forKey: .isStorageUnlocked)
        try container.encode(isCockpitUnlocked, forKey: .isCockpitUnlocked)
        try container.encode(powerState, forKey: .powerState)
        try container.encode(albumBook, forKey: .albumBook)
        try container.encode(selectedChallengeLabels, forKey: .selectedChallengeLabels)
        try container.encode(chapterChallengeSelections, forKey: .chapterChallengeSelections)
        try container.encode(storyRandomSeed, forKey: .storyRandomSeed)
        try container.encode(processedMilestoneIDs, forKey: .processedMilestoneIDs)
        try container.encode(deliveredDialogueIDs, forKey: .deliveredDialogueIDs)
        try container.encode(processedCommandIDs, forKey: .processedCommandIDs)
        try container.encode(latestCheckpoint, forKey: .latestCheckpoint)
    }

    private static func migrateLegacyEasel(
        id: String,
        definitions: [DrawingMissionDefinition],
        completedObjectiveIDs: Set<String>,
        selections: [String: [String]],
        completions: [String: [String]],
        state: inout StoryState
    ) {
        var remainingLabels = selections[id] ?? []
        var assignment: [String: String] = [:]

        for definition in definitions {
            let matchingIndex = remainingLabels.firstIndex { label in
                CoreMLLabelCatalog.categoryLabels[definition.category]?.contains(label.lowercased()) == true
            }
            let index = matchingIndex ?? (remainingLabels.isEmpty ? nil : remainingLabels.startIndex)
            if let index {
                assignment[definition.id] = remainingLabels.remove(at: index)
            }
        }
        state.selectedChallengeLabels.merge(assignment) { current, _ in current }

        if completedObjectiveIDs.contains(id) {
            state.completedChallengeIDs.formUnion(definitions.map(\.id))
        } else {
            let completedLabels = completions[id] ?? []
            for label in completedLabels {
                if let challengeID = assignment.first(where: { $0.value == label })?.key {
                    state.completedChallengeIDs.insert(challengeID)
                } else if let next = definitions.first(where: { !state.completedChallengeIDs.contains($0.id) }) {
                    state.completedChallengeIDs.insert(next.id)
                }
            }
        }
    }
}

struct PlayerSurvivalState: Codable, Equatable, Sendable {
    let playerID: String
    var energy: Double
}

struct StoryProgress: Codable, Equatable, Sendable {
    let energy: Double
    let intelligence: Double
    let engineProgress: Double
}

struct GameSessionStats: Codable, Equatable, Sendable {
    var elapsedTime: TimeInterval = 0
    var drawingAttempts = 0
    var successfulDrawings = 0
    var kitchenRestores = 0
}

struct StorySaveSnapshot: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 2

    let schemaVersion: Int
    var sharedStory: StoryState
    var localSurvival: PlayerSurvivalState
    var safeSpawn: CGPoint
    var stats: GameSessionStats
    var savedAt: Date

    init(
        sharedStory: StoryState,
        localSurvival: PlayerSurvivalState,
        safeSpawn: CGPoint,
        stats: GameSessionStats,
        savedAt: Date = .now
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.sharedStory = sharedStory
        self.localSurvival = localSurvival
        self.safeSpawn = safeSpawn
        self.stats = stats
        self.savedAt = savedAt
    }
}
