import Foundation

struct DrawingMissionDefinition: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let chapter: StoryChapter
    let missionID: MissionID
    let roomID: RoomID
    let category: DrawingCategory
    let fallbackCategory: DrawingCategory
    let order: Int
    let intelligenceReward: Double
    let engineReward: Double
    let persistsAsRepairedWorldProp: Bool
    let confidenceThreshold: Double

    init(
        id: String,
        chapter: StoryChapter,
        missionID: MissionID,
        roomID: RoomID,
        category: DrawingCategory,
        fallbackCategory: DrawingCategory = .otherObject,
        order: Int,
        intelligenceReward: Double = 0,
        engineReward: Double = 0,
        persistsAsRepairedWorldProp: Bool = false,
        confidenceThreshold: Double = 0.50
    ) {
        self.id = id
        self.chapter = chapter
        self.missionID = missionID
        self.roomID = roomID
        self.category = category
        self.fallbackCategory = fallbackCategory
        self.order = order
        self.intelligenceReward = intelligenceReward
        self.engineReward = engineReward
        self.persistsAsRepairedWorldProp = persistsAsRepairedWorldProp
        self.confidenceThreshold = confidenceThreshold
    }
}
