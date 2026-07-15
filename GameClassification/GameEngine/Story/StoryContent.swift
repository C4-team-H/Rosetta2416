import Foundation

enum StoryContent {
    static let objectives: [StoryObjectiveDefinition] = [
        objective("reach-laboratory", .sleepingRoom, .laboratory, "Reach the Laboratory", "Find the laboratory and enter it.", [], .none, .roomEntry(.laboratory)),

        objective("lab-terminal-repair", .laboratory, .laboratory, "Repair Communication Terminal", "Draw a radio to restore the terminal.", ["reach-laboratory"], reward(ai: 10), drawing("radio", "RADIO")),
        objective("lab-memory-repair", .laboratory, .laboratory, "Repair Memory Processor", "Draw a brain to reconnect AI memory.", ["reach-laboratory"], reward(ai: 10), drawing("brain", "BRAIN")),
        objective("lab-scanner-repair", .laboratory, .laboratory, "Repair Navigation Scanner", "Draw binoculars to restore long-range scanning.", ["reach-laboratory"], reward(ai: 10), drawing("binoculars", "BINOCULARS")),

        objective("engine-power-connector", .enginePhaseOne, .engine, "Reconnect Power Connector", "Draw a power outlet to rebuild the connector.", labIDs, reward(engine: 5), drawing("power outlet", "POWER OUTLET")),
        objective("engine-ignition-coil", .enginePhaseOne, .engine, "Repair Ignition Coil", "Draw a lightbulb to restart the ignition relay.", ["engine-power-connector"], reward(engine: 5), drawing("lightbulb", "LIGHTBULB")),

        objective("engine-cooling-valve", .enginePhaseTwo, .engine, "Restore Cooling Valve", "Draw a fan to restart coolant circulation.", ["engine-ignition-coil"], reward(ai: 3, engine: 10), drawing("fan", "FAN")),
        objective("engine-control-relay", .enginePhaseTwo, .engine, "Repair Control Relay", "Draw a computer monitor to rebuild engine control.", ["engine-cooling-valve"], reward(ai: 3, engine: 10), drawing("computer monitor", "COMPUTER MONITOR")),
        objective("engine-reactor-link", .enginePhaseTwo, .engine, "Reconnect Reactor Link", "Draw a satellite to synchronize the reactor link.", ["engine-control-relay"], reward(ai: 4, engine: 10), drawing("satellite", "SATELLITE")),
        objective("engine-pressure-feed", .enginePhaseTwo, .engine, "Repair Pressure Feed", "Draw a fire hydrant to restore the pressure feed.", ["engine-reactor-link"], reward(ai: 5, engine: 10), drawing("fire hydrant", "FIRE HYDRANT")),
        objective("engine-calibration-port", .enginePhaseTwo, .engine, "Calibrate Engine Port", "Draw a screwdriver to calibrate the port.", ["engine-pressure-feed"], reward(ai: 5, engine: 10), drawing("screwdriver", "SCREWDRIVER")),

        objective("storage-door-controller", .storage, .storage, "Repair Storage Controller", "Draw a key to restore door control.", [], .none, drawing("key", "KEY")),
        objective("storage-tool-terminal", .storage, .storage, "Repair Tool Terminal", "Draw a calculator to identify compatible tools.", ["storage-door-controller"], .none, drawing("calculator", "CALCULATOR")),
        objective("storage-robotic-arm", .storage, .storage, "Repair Robotic Arm", "Draw a hand to restore the robotic manipulator.", ["storage-tool-terminal"], .none, drawing("hand", "HAND")),
        objective("storage-calibration-unit", .storage, .storage, "Repair Calibration Unit", "Draw a screwdriver to release the advanced toolkit.", ["storage-robotic-arm"], .none, drawing("screwdriver", "SCREWDRIVER")),

        objective("engine-reactor-stabilizer", .engineFinal, .engine, "Stabilize the Reactor", "Draw a sun to stabilize the reactor.", storageIDs, reward(ai: 8, engine: 8), drawing("sun", "SUN")),
        objective("engine-core-reconnect", .engineFinal, .engine, "Reconnect Engine Core", "Draw a power outlet to reconnect the core.", ["engine-reactor-stabilizer"], reward(ai: 8, engine: 8), drawing("power outlet", "POWER OUTLET")),
        objective("engine-propulsion-calibration", .engineFinal, .engine, "Calibrate Propulsion", "Draw a rocket to calibrate propulsion.", ["engine-core-reconnect"], reward(ai: 8, engine: 8), drawing("rocket", "ROCKET")),
        objective("engine-cooling-restart", .engineFinal, .engine, "Restart Cooling", "Draw a fan to restart cooling.", ["engine-propulsion-calibration"], reward(ai: 8, engine: 8), drawing("fan", "FAN")),
        objective("engine-navigation-sync", .engineFinal, .engine, "Synchronize Navigation", "Draw a satellite to finish navigation synchronization.", ["engine-cooling-restart"], reward(ai: 8, engine: 8), drawing("satellite", "SATELLITE")),

        objective("cockpit-navigation-control", .cockpit, .cockpit, "Restore Navigation Control", "Draw a ship to activate navigation.", [], .none, drawing("ship", "SHIP")),
        objective("cockpit-communications", .cockpit, .cockpit, "Reconnect Communications", "Draw a radio to restore communications.", ["cockpit-navigation-control"], .none, drawing("radio", "RADIO")),
        objective("cockpit-flight-console", .cockpit, .cockpit, "Calibrate Flight Console", "Draw a computer keyboard to complete recovery.", ["cockpit-communications"], .none, drawing("keyboard-computer", "COMPUTER KEYBOARD"))
    ]

    static let labIDs = ["lab-terminal-repair", "lab-memory-repair", "lab-scanner-repair"]
    static let enginePhaseOneIDs = ["engine-power-connector", "engine-ignition-coil"]
    static let enginePhaseTwoDisruptionIDs = ["engine-cooling-valve", "engine-control-relay", "engine-reactor-link"]
    static let enginePhaseTwoIDs = enginePhaseTwoDisruptionIDs + ["engine-pressure-feed", "engine-calibration-port"]
    static let storageIDs = ["storage-door-controller", "storage-tool-terminal", "storage-robotic-arm", "storage-calibration-unit"]
    static let engineFinalIDs = ["engine-reactor-stabilizer", "engine-core-reconnect", "engine-propulsion-calibration", "engine-cooling-restart", "engine-navigation-sync"]
    static let cockpitIDs = ["cockpit-navigation-control", "cockpit-communications", "cockpit-flight-console"]

    static let roomRules: [RoomAccessRule] = [
        RoomAccessRule(roomID: .sleepingRoom, requiredChapter: nil, minimumIntelligence: nil, minimumEngineProgress: nil, requiresAdvancedTools: false),
        RoomAccessRule(roomID: .laboratory, requiredChapter: nil, minimumIntelligence: nil, minimumEngineProgress: nil, requiresAdvancedTools: false),
        RoomAccessRule(roomID: .kitchen, requiredChapter: nil, minimumIntelligence: nil, minimumEngineProgress: nil, requiresAdvancedTools: false),
        RoomAccessRule(roomID: .engine, requiredChapter: .enginePhaseOne, minimumIntelligence: 40, minimumEngineProgress: nil, requiresAdvancedTools: false),
        RoomAccessRule(roomID: .storage, requiredChapter: .engineBlocked, minimumIntelligence: nil, minimumEngineProgress: 60, requiresAdvancedTools: false),
        RoomAccessRule(roomID: .cockpit, requiredChapter: .cockpit, minimumIntelligence: 100, minimumEngineProgress: 100, requiresAdvancedTools: false)
    ]

    static func definition(id: String) -> StoryObjectiveDefinition? {
        objectives.first { $0.id == id }
    }

    private static func objective(
        _ id: String,
        _ chapter: StoryChapter,
        _ room: RoomID,
        _ title: String,
        _ description: String,
        _ requirements: [String],
        _ reward: StoryProgressReward,
        _ kind: ObjectiveKind
    ) -> StoryObjectiveDefinition {
        StoryObjectiveDefinition(
            id: id,
            chapter: chapter,
            roomID: room,
            title: title,
            description: description,
            requiredObjectiveIDs: requirements,
            reward: reward,
            kind: kind,
            priority: .main
        )
    }

    private static func reward(ai: Double = 0, engine: Double = 0) -> StoryProgressReward {
        StoryProgressReward(intelligence: ai, engine: engine)
    }

    private static func drawing(_ label: String, _ displayName: String) -> ObjectiveKind {
        .drawing(DrawingPrompt(expectedLabel: label, displayName: displayName))
    }
}
