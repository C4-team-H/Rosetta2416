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
        AIDialogueLine(id: "intro-1", chapter: .sleepingRoom, trigger: .chapterEntered(.sleepingRoom), text: "Sys... systems damaged. Solar flare impact detected. Find laboratory.", priority: 100),
        AIDialogueLine(id: "lab-complete", chapter: .engineInitial, trigger: .chapterEntered(.engineInitial), text: "Communication restored.\nThe ship’s primary engine is offline.\nProceed to the Engine Room.", priority: 100),
        AIDialogueLine(id: "power-basic", chapter: .engineInitial, trigger: .powerChanged(.basicPower), text: "Primary lighting restored. Flashlight no longer required.", priority: 100),
        AIDialogueLine(id: "power-disrupted", chapter: .engineInitial, trigger: .powerChanged(.disrupted), text: "Warning. Engine repair disrupted primary lighting. Emergency flashlight restored.", priority: 100),
        AIDialogueLine(id: "storage-route", chapter: .storage, trigger: .chapterEntered(.storage), text: "Repair progress halted.\nAdvanced calibration tools are required.\nProceed to Storage.", priority: 100),
        AIDialogueLine(id: "tools-acquired", chapter: .engineFinal, trigger: .chapterEntered(.engineFinal), text: "Advanced repair tools acquired.\nReturn to the Engine Room.", priority: 100),
        AIDialogueLine(id: "engine-complete", chapter: .cockpit, trigger: .chapterEntered(.cockpit), text: "Engine restoration complete.\nCockpit access restored.", priority: 100),
        AIDialogueLine(id: "album-hint", chapter: .sleepingRoom, trigger: .albumHint, text: "Having trouble drawing?\nCheck the Album Book in the Sleeping Room for references.", priority: 110),
        AIDialogueLine(id: "victory", chapter: .victory, trigger: .victory, text: "All systems restored.\nNavigation control is responding.\nYou brought us back online.", priority: 100)
    ]
}
