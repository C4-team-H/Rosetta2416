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
        guard let url = bundle.url(forResource: "StoryDialogue", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let resources = try? JSONDecoder().decode([DialogueResourceLine].self, from: data) else {
            return fallback
        }
        return resources.compactMap(\.line)
    }

    static let fallback: [AIDialogueLine] = [
        AIDialogueLine(id: "intro-1", chapter: .sleepingRoom, trigger: .chapterEntered(.sleepingRoom), text: "Sys... systems damaged. Find... laboratory.", priority: 100),
        AIDialogueLine(id: "lab-complete", chapter: .enginePhaseOne, trigger: .chapterEntered(.enginePhaseOne), text: "Communication restored. Proceed to the Engine Room.", priority: 100),
        AIDialogueLine(id: "power-basic", chapter: .enginePhaseOne, trigger: .powerChanged(.basicPower), text: "Primary lighting restored. Flashlight no longer required.", priority: 100),
        AIDialogueLine(id: "power-disrupted", chapter: .enginePhaseOne, trigger: .powerChanged(.disrupted), text: "Warning. Engine repair disrupted primary lighting. Emergency flashlight restored.", priority: 100),
        AIDialogueLine(id: "storage-route", chapter: .engineBlocked, trigger: .chapterEntered(.engineBlocked), text: "Repair halted. Retrieve advanced tools from Storage.", priority: 100),
        AIDialogueLine(id: "tools-acquired", chapter: .engineFinal, trigger: .chapterEntered(.engineFinal), text: "Advanced repair tools acquired. Return to the Engine Room.", priority: 100),
        AIDialogueLine(id: "engine-complete", chapter: .cockpit, trigger: .chapterEntered(.cockpit), text: "Engine restoration complete. Cockpit access restored.", priority: 100),
        AIDialogueLine(id: "victory", chapter: .completed, trigger: .victory, text: "All systems restored. You brought us back online.", priority: 100)
    ]
}
