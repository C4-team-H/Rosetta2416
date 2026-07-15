import Foundation

@MainActor
final class AIDialogueManager {
    private let lines: [AIDialogueLine]

    init(lines: [AIDialogueLine]? = nil) {
        self.lines = lines ?? StoryDialogueLoader.load()
    }

    func nextLine(for trigger: DialogueTrigger, story: SharedStoryState) -> AIDialogueLine? {
        lines
            .filter {
                $0.trigger == trigger
                    && !story.deliveredDialogueIDs.contains($0.id)
                    && ($0.minimumIntelligence == nil || story.intelligence >= $0.minimumIntelligence!)
                    && ($0.maximumIntelligence == nil || story.intelligence <= $0.maximumIntelligence!)
            }
            .sorted { $0.priority > $1.priority }
            .first
    }
}
