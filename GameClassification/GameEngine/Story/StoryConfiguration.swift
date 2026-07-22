import Foundation

enum StoryConfiguration {
    static let laboratoryChallenges = [
        challenge("lab-memory-repair", .laboratory, .restoreAI, .laboratory, .animal, 1, intelligence: 10),
        challenge("lab-scanner-repair", .laboratory, .restoreAI, .laboratory, .plant, 2, intelligence: 10),
        challenge("lab-terminal-repair", .laboratory, .restoreAI, .laboratory, .human, 3, intelligence: 10)
    ]

    static let engineInitialChallenges = [
        challenge("engine-ignition-coil", .engineInitial, .repairEngine, .engine, .landscape, 1, engine: 10),
        challenge("engine-power-connector", .engineInitial, .repairEngine, .engine, .transportation, 2, engine: 10),
        challenge("engine-control-relay", .engineInitial, .repairEngine, .engine, .otherObject, 3, engine: 10, fallback: .tool),
        challenge("engine-cooling-valve", .engineInitial, .repairEngine, .engine, .landscape, 4, engine: 10),
        challenge("engine-cooling-restart", .engineInitial, .repairEngine, .engine, .transportation, 5, engine: 10),
        challenge("engine-reactor-link", .engineInitial, .repairEngine, .engine, .otherObject, 6, engine: 10, fallback: .tool)
    ]

    static let storageChallenges = [
        challenge("storage-tool-terminal", .storage, .retrieveCalibrationTools, .storage, .tool, 1, repairedProp: true),
        challenge("storage-robotic-arm", .storage, .retrieveCalibrationTools, .storage, .equipment, 2, repairedProp: true),
        challenge("storage-calibration-unit", .storage, .retrieveCalibrationTools, .storage, .furniture, 3, repairedProp: true)
    ]

    static let engineFinalChallenges = [
        challenge("engine-calibration-port", .engineFinal, .continueEngineRepair, .engine, .electronics, 1, intelligence: 15, engine: 10),
        challenge("engine-core-reconnect", .engineFinal, .continueEngineRepair, .engine, .electronics, 2, intelligence: 15, engine: 10),
        challenge("engine-propulsion-calibration", .engineFinal, .continueEngineRepair, .engine, .weapon, 3, intelligence: 15, engine: 10),
        challenge("engine-reactor-stabilizer", .engineFinal, .continueEngineRepair, .engine, .electronics, 4, intelligence: 15, engine: 10)
    ]

    static let cockpitChallenges = [
        challenge("cockpit-communications", .cockpit, .initiateLaunch, .cockpit, .celestial, 1, fallback: .landscape),
        challenge("cockpit-navigation-control", .cockpit, .initiateLaunch, .cockpit, .celestial, 2, fallback: .landscape),
        challenge("cockpit-flight-console", .cockpit, .initiateLaunch, .cockpit, .celestial, 3, fallback: .landscape)
    ]

    static let challenges = laboratoryChallenges + engineInitialChallenges + storageChallenges
        + engineFinalChallenges + cockpitChallenges

    static let challengeIDs = Set(challenges.map(\.id))
    static let unusedStationIDs: Set<String> = [
        "engine-pressure-feed", "engine-navigation-sync", "storage-door-controller"
    ]

    static func challenges(for chapter: StoryChapter) -> [DrawingMissionDefinition] {
        challenges.filter { $0.chapter == chapter }.sorted { $0.order < $1.order }
    }

    static func definition(id: String) -> DrawingMissionDefinition? {
        challenges.first { $0.id == id }
    }

    static func mission(for chapter: StoryChapter, activeChallengeID: String? = nil) -> MissionState? {
        switch chapter {
        case .sleepingRoom:
            return MissionState(id: .findLaboratory, title: "Find the Laboratory.", targetRoomID: .laboratory, activeChallengeID: nil)
        case .laboratory:
            return MissionState(id: .restoreAI, title: "Restore the AI.", targetRoomID: .laboratory, activeChallengeID: activeChallengeID)
        case .engineInitial:
            return MissionState(id: .repairEngine, title: "Repair the Engine.", targetRoomID: .engine, activeChallengeID: activeChallengeID)
        case .storage:
            return MissionState(id: .retrieveCalibrationTools, title: "Retrieve the calibration tools from Storage.", targetRoomID: .storage, activeChallengeID: activeChallengeID)
        case .engineFinal:
            return MissionState(id: .continueEngineRepair, title: "Continue repairing the Engine.", targetRoomID: .engine, activeChallengeID: activeChallengeID)
        case .cockpit:
            return MissionState(id: .initiateLaunch, title: "Go to the Cockpit and initiate launch.", targetRoomID: .cockpit, activeChallengeID: activeChallengeID)
        case .victory:
            return nil
        }
    }

    private static func challenge(
        _ id: String,
        _ chapter: StoryChapter,
        _ mission: MissionID,
        _ room: RoomID,
        _ category: DrawingCategory,
        _ order: Int,
        intelligence: Double = 0,
        engine: Double = 0,
        fallback: DrawingCategory = .otherObject,
        repairedProp: Bool = false
    ) -> DrawingMissionDefinition {
        DrawingMissionDefinition(
            id: id,
            chapter: chapter,
            missionID: mission,
            roomID: room,
            category: category,
            fallbackCategory: fallback,
            order: order,
            intelligenceReward: intelligence,
            engineReward: engine,
            persistsAsRepairedWorldProp: repairedProp
        )
    }
}
