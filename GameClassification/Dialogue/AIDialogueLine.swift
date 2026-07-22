import Foundation

struct AIDialogueLine: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let chapter: StoryChapter
    let trigger: DialogueTrigger
    let text: String
    let priority: Int
    let minimumIntelligence: Double?
    let maximumIntelligence: Double?

    init(
        id: String,
        chapter: StoryChapter,
        trigger: DialogueTrigger,
        text: String,
        priority: Int,
        minimumIntelligence: Double? = nil,
        maximumIntelligence: Double? = nil
    ) {
        self.id = id
        self.chapter = chapter
        self.trigger = trigger
        self.text = text
        self.priority = priority
        self.minimumIntelligence = minimumIntelligence
        self.maximumIntelligence = maximumIntelligence
    }
}

private struct DialogueResourceLine: Decodable {
    let id: String
    let chapter: StoryChapter
    let trigger: String
    let value: String?
    let text: String
    let priority: Int
    let minimumIntelligence: Double?
    let maximumIntelligence: Double?

    var line: AIDialogueLine? {
        let mappedTrigger: DialogueTrigger?
        switch trigger {
        case "chapter":
            mappedTrigger = .chapterEntered(chapter)
        case "objective":
            mappedTrigger = value.map(DialogueTrigger.objectiveCompleted)
        case "power":
            mappedTrigger = value.flatMap(ShipPowerState.init(rawValue:)).map(DialogueTrigger.powerChanged)
        case "roomDenied":
            mappedTrigger = value.flatMap(RoomID.init(rawValue:)).map(DialogueTrigger.roomDenied)
        case "roomEntered":
            mappedTrigger = value.flatMap(RoomID.init(rawValue:)).map(DialogueTrigger.roomEntered)
        case "albumHint":
            mappedTrigger = .albumHint
        case "victory":
            mappedTrigger = .victory
        default:
            mappedTrigger = nil
        }
        guard let mappedTrigger else { return nil }
        return AIDialogueLine(
            id: id,
            chapter: chapter,
            trigger: mappedTrigger,
            text: text,
            priority: priority,
            minimumIntelligence: minimumIntelligence,
            maximumIntelligence: maximumIntelligence
        )
    }
}

enum StoryDialogueLoader {
    static func load(bundle: Bundle = .main) -> [AIDialogueLine] {
        let possibleUrls = [
            bundle.url(forResource: "StoryDialogue", withExtension: "json"),
            bundle.url(forResource: "StoryDiaglogue", withExtension: "json"),
            bundle.url(forResource: "StoryDialogue", withExtension: "json", subdirectory: "Dialogue"),
            bundle.url(forResource: "StoryDiaglogue", withExtension: "json", subdirectory: "Dialogue")
        ].compactMap { $0 }

        for url in possibleUrls {
            if let data = try? Data(contentsOf: url),
               let resources = try? JSONDecoder().decode([DialogueResourceLine].self, from: data) {
                return resources.compactMap(\.line)
            }
        }
        return fallback
    }

    static let fallback: [AIDialogueLine] = [
        AIDialogueLine(id: "intro-1", chapter: .sleepingRoom, trigger: .chapterEntered(.sleepingRoom), text: "Your ship just got hit by solar flare, everything in every room is practically broken. Fix the engine in this ship until 100% to continue your journey.", priority: 100),
        AIDialogueLine(id: "intro-2", chapter: .sleepingRoom, trigger: .chapterEntered(.sleepingRoom), text: "Go to the Lab to check on AI in this ship.", priority: 90),
        AIDialogueLine(id: "lab-entered-1", chapter: .laboratory, trigger: .chapterEntered(.laboratory), text: "Robo: ??/?!?!?;??!!! THIS SHIP IS BROKEN. GO TO THE SCREEN ??!/? IN EVERY ROOM, AND DRAW EARTH OBJECTS.", priority: 100),
        AIDialogueLine(id: "lab-entered-2", chapter: .laboratory, trigger: .chapterEntered(.laboratory), text: "Astronout: This thing suffered from Semantic Aphasia.\n(Semantic aphasia is a language disorder where the brain loses the connection between words and their meanings).", priority: 90),
        AIDialogueLine(id: "lab-entered-3", chapter: .laboratory, trigger: .chapterEntered(.laboratory), text: "Astronout: I should start fixing thing and watchout with my energy.", priority: 80),
        AIDialogueLine(id: "lab-complete", chapter: .engineInitial, trigger: .chapterEntered(.engineInitial), text: "Go to the Engine Room and start working on it.", priority: 100),
        AIDialogueLine(id: "power-basic", chapter: .engineInitial, trigger: .powerChanged(.basicPower), text: "Good! Just enough electricity from the engine to turn on the lamp.", priority: 100),
        AIDialogueLine(id: "power-disrupted", chapter: .engineInitial, trigger: .powerChanged(.disrupted), text: "Power outage, you must touch something wrong in the engine. Let’s keep rolling!", priority: 100),
        AIDialogueLine(id: "storage-route", chapter: .storage, trigger: .chapterEntered(.storage), text: "Robo: You need advance tools to continue fixing the engine, go to the Storage Room.", priority: 100),
        AIDialogueLine(id: "tools-acquired", chapter: .engineFinal, trigger: .chapterEntered(.engineFinal), text: "You got all you need, go back to the Engine Room and continue fixing.", priority: 100),
        AIDialogueLine(id: "engine-complete", chapter: .cockpit, trigger: .chapterEntered(.cockpit), text: "Congratulations! My intelligence and the engine is in 100% now. Go to the Cockpit!", priority: 100),
        AIDialogueLine(id: "album-hint", chapter: .sleepingRoom, trigger: .albumHint, text: "Robo: Having trouble drawing? Check the Album Book in the Sleeping Room for references.", priority: 110),
        AIDialogueLine(id: "kitchen-entered", chapter: .sleepingRoom, trigger: .roomEntered(.kitchen), text: "Robo: You can add your energy by draw food at the kitchen", priority: 100),
        AIDialogueLine(id: "victory", chapter: .victory, trigger: .victory, text: "All systems restored.\nNavigation control is responding.\nYou brought us back online.", priority: 100)
    ]
}
