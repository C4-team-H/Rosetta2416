import Foundation

enum StoryContent {

    // MARK: - Category Pools

    static let hewanPool: [DrawingPrompt] = [
        "ant", "bee", "butterfly", "camel", "cat", "cow", "crab", "crocodile",
        "dog", "dolphin", "dragon", "elephant", "fish", "flying bird", "frog",
        "giraffe", "hedgehog", "horse", "kangaroo", "lion", "lobster", "monkey",
        "mouse (animal)", "octopus", "owl", "penguin", "pig", "rabbit", "rooster",
        "scorpion", "sea turtle", "shark", "sheep", "snail", "snake", "spider",
        "squirrel", "swan", "tiger", "zebra", "feather"
    ].map { prompt($0) }

    static let tanamanPool: [DrawingPrompt] = [
        "cactus", "flower with stem", "leaf", "palm tree", "potted plant", "tree"
    ].map { prompt($0) }

    static let manusiaPool: [DrawingPrompt] = [
        "brain", "crown", "ear", "eye", "eyeglasses", "face", "foot", "hand",
        "hat", "helmet", "human-skeleton", "mouth", "nose", "pant",
        "person sitting", "person walking", "shoe", "skull", "socks",
        "suitcase", "t-shirt", "tooth", "wrist-watch"
    ].map { prompt($0) }

    static let landscapePool: [DrawingPrompt] = [
        "castle", "cloud", "fire hydrant", "house", "rainbow", "skyscraper",
        "streetlight", "tent", "traffic light", "windmill"
    ].map { prompt($0) }

    static let transportasiPool: [DrawingPrompt] = [
        "airplane", "bicycle", "helicopter", "kayak", "rollerblades", "sedan",
        "ship", "skateboard", "rocket", "submarine", "train"
    ].map { prompt($0) }

    static let otherPool: [DrawingPrompt] = [
        "diamond", "envelope", "gift", "parachute", "teddy-bear"
    ].map { prompt($0) }

    static let elektronikPool: [DrawingPrompt] = [
        "alarm clock", "camera", "computer monitor", "head-phones",
        "keyboard-computer", "laptop", "microphone", "radio", "satellite"
    ].map { prompt($0) }

    static let senjataPool: [DrawingPrompt] = [
        "cannon"
    ].map { prompt($0) }

    static let alatPool: [DrawingPrompt] = [
        "backpack", "axe", "binoculars", "book", "bowl", "calculator", "comb",
        "computer-mouse", "flashlight", "fork", "frying-pan", "hammer",
        "hourglass", "key", "knife", "ladder", "microscope", "mug",
        "paper clip", "pen", "scissors", "screwdriver", "spoon", "stapler",
        "syringe", "teapot", "toothbrush", "wheel", "wineglass", "power outlet"
    ].map { prompt($0) }

    static let furniturePool: [DrawingPrompt] = [
        "bed", "bell", "cabinet", "candle", "chair", "chandelier", "door",
        "fan", "guitar", "lightbulb", "table", "tennis-racket",
        "umbrella"
    ].map { prompt($0) }

    static let bendaLangitPool: [DrawingPrompt] = [
        DrawingPrompt(expectedLabel: "moon", displayName: "MOON"),
        DrawingPrompt(expectedLabel: "sun", displayName: "SUN"),
        DrawingPrompt(expectedLabel: "ufo", displayName: "UFO")
    ]

    // MARK: - Objectives

    static let objectives: [StoryObjectiveDefinition] = [
        // Sleeping Room
        objective("reach-laboratory", .sleepingRoom, .laboratory, "Reach the Laboratory", "Find the laboratory and enter it.", [], .none, .roomEntry(.laboratory)),

        // Laboratory — 1 easel, 3 random from hewan + tanaman + manusia
        objective("lab-easel", .laboratory, .laboratory, "Restore AI Systems", "Draw 3 objects to restore the ship's AI.",
                  ["reach-laboratory"],
                  .none,
                  // .easel(EaselDefinition(pool: hewanPool + tanamanPool + manusiaPool, count: 3, perDrawingReward: StoryProgressReward(intelligence: 10, engine: 0)))),
                  .easel(EaselDefinition(pool: [prompt("eyeglasses"), prompt("spider"), prompt("keyboard-computer")], count: 3, perDrawingReward: StoryProgressReward(intelligence: 10, engine: 0)))),

        // Engine Room Easel 1 — 6 random from landscape + transportasi + other
        // Each drawing gives +10 engine progress.
        // Milestones: engine 10 → basicPower, engine 40 → disruption, engine 60 → storage opens.
        objective("engine-easel-1", .enginePhaseOne, .engine, "Primary Engine Repair", "Draw 6 objects to restore the engine to 60%.",
                  ["lab-easel"],
                  .none,
                  .easel(EaselDefinition(pool: landscapePool + transportasiPool + otherPool, count: 6, perDrawingReward: StoryProgressReward(intelligence: 3, engine: 10)))),

        // Storage — 1 easel, 3 random from alat-alat dan perkakas + furniture
        objective("storage-easel", .storage, .storage, "Retrieve Advanced Tools", "Draw 3 objects to unlock the advanced toolkit.",
                  [],
                  .none,
                  .easel(EaselDefinition(pool: alatPool + furniturePool, count: 3, perDrawingReward: StoryProgressReward(intelligence: 0, engine: 0)))),

        // Engine Room Easel 2 — 4 random from elektronik + senjata
        objective("engine-easel-2", .engineFinal, .engine, "Final Engine Repair", "Draw 4 objects to finish engine repairs.",
                  ["storage-easel"],
                  .none,
                  .easel(EaselDefinition(pool: elektronikPool + senjataPool, count: 4, perDrawingReward: StoryProgressReward(intelligence: 10, engine: 10)))),

        // Cockpit — 1 easel, 3 fixed: moon, sun, ufo
        objective("cockpit-easel", .cockpit, .cockpit, "Launch Sequence", "Draw 3 celestial objects to complete the launch sequence.",
                  [],
                  .none,
                  .easel(EaselDefinition(pool: bendaLangitPool, count: 3, perDrawingReward: StoryProgressReward(intelligence: 0, engine: 0))))
    ]

    // MARK: - Objective ID Lists

    static let labIDs = ["lab-easel"]
    static let engineEaselOneIDs = ["engine-easel-1"]
    static let storageIDs = ["storage-easel"]
    static let engineFinalIDs = ["engine-easel-2"]
    static let cockpitIDs = ["cockpit-easel"]

    // MARK: - Room Access Rules

    static let roomRules: [RoomAccessRule] = [
        RoomAccessRule(roomID: .sleepingRoom, requiredChapter: nil, minimumIntelligence: nil, minimumEngineProgress: nil, requiresAdvancedTools: false),
        RoomAccessRule(roomID: .laboratory, requiredChapter: nil, minimumIntelligence: nil, minimumEngineProgress: nil, requiresAdvancedTools: false),
        RoomAccessRule(roomID: .kitchen, requiredChapter: nil, minimumIntelligence: nil, minimumEngineProgress: nil, requiresAdvancedTools: false),
        RoomAccessRule(roomID: .engine, requiredChapter: .enginePhaseOne, minimumIntelligence: 40, minimumEngineProgress: nil, requiresAdvancedTools: false),
        RoomAccessRule(roomID: .storage, requiredChapter: .engineBlocked, minimumIntelligence: nil, minimumEngineProgress: 60, requiresAdvancedTools: false),
        RoomAccessRule(roomID: .cockpit, requiredChapter: .cockpit, minimumIntelligence: 100, minimumEngineProgress: 100, requiresAdvancedTools: false)
    ]

    // MARK: - Helpers

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

    private static func prompt(_ label: String) -> DrawingPrompt {
        DrawingPrompt(expectedLabel: label, displayName: label.uppercased())
    }
}
