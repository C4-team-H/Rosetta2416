import Foundation

struct RoomAccessRule: Codable, Equatable, Sendable {
    let roomID: RoomID
    let requiredChapter: StoryChapter?
    let minimumIntelligence: Double?
    let minimumEngineProgress: Double?
    let requiresAdvancedTools: Bool

    func allows(_ state: SharedStoryState) -> Bool {
        if let requiredChapter, state.currentChapter.order < requiredChapter.order { return false }
        if let minimumIntelligence, state.intelligence < minimumIntelligence { return false }
        if let minimumEngineProgress, state.engineProgress < minimumEngineProgress { return false }
        if requiresAdvancedTools && !state.hasAdvancedTools { return false }
        return true
    }
}

