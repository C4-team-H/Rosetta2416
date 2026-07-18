import CoreGraphics
import Foundation

enum StoryChapter: String, Codable, CaseIterable, Sendable {
    case sleepingRoom
    case laboratory
    case enginePhaseOne
    case engineBlocked
    case storage
    case engineFinal
    case cockpit
    case completed

    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

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

enum ShipPowerState: String, Codable, Sendable {
    case emergency
    case basicPower
    case disrupted
    case fullyRestored
}

enum CheckpointID: String, Codable, CaseIterable, Sendable {
    case sleepingRoom
    case laboratory
    case enginePhaseOne
    case engineDisruption
    case engineBlocked
    case storage
    case engineFinal
    case cockpit
}

enum DialogueTrigger: Codable, Equatable, Sendable {
    case chapterEntered(StoryChapter)
    case objectiveCompleted(String)
    case powerChanged(ShipPowerState)
    case roomDenied(RoomID)
    case energyLow
    case victory
}

enum StoryCutscene: String, Codable, Equatable, Sendable {
    case electricalDisruption
    case engineRestoration
}

struct DrawingPrompt: Codable, Equatable, Sendable {
    let expectedLabel: String
    let displayName: String
    let confidenceThreshold: Double

    init(expectedLabel: String, displayName: String, confidenceThreshold: Double = 0.50) {
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

struct SharedStoryState: Codable, Equatable, Sendable {
    var currentChapter: StoryChapter
    var completedObjectiveIDs: Set<String>
    var intelligence: Double
    var engineProgress: Double
    var hasAdvancedTools: Bool
    var powerState: ShipPowerState
    var deliveredDialogueIDs: Set<String>
    var processedCommandIDs: Set<UUID>
    var latestCheckpoint: CheckpointID
    var easelSelectedLabels: [String: [String]]
    var easelCompletedLabels: [String: [String]]
    var kitchenCompletedLabels: [String]
    var hasOpenedAlbum: Bool

    static let initial = SharedStoryState(
        currentChapter: .sleepingRoom,
        completedObjectiveIDs: [],
        intelligence: 10,
        engineProgress: 0,
        hasAdvancedTools: false,
        powerState: .emergency,
        deliveredDialogueIDs: [],
        processedCommandIDs: [],
        latestCheckpoint: .sleepingRoom,
        easelSelectedLabels: [:],
        easelCompletedLabels: [:],
        kitchenCompletedLabels: [],
        hasOpenedAlbum: false
    )

    var isMainPowerOnline: Bool {
        powerState == .basicPower || powerState == .fullyRestored
    }

    var isCockpitUnlocked: Bool {
        engineProgress >= 100 && intelligence >= 100
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
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    var sharedStory: SharedStoryState
    var localSurvival: PlayerSurvivalState
    var safeSpawn: CGPoint
    var stats: GameSessionStats
    var savedAt: Date

    init(
        sharedStory: SharedStoryState,
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
