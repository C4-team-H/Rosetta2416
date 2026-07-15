import Foundation

@MainActor
final class MissionSystem {
    private let story: StoryProgressionSystem

    init(story: StoryProgressionSystem) {
        self.story = story
    }

    func interactableObjective(id: String, from room: RoomID?) -> StoryObjectiveDefinition? {
        guard let objective = story.objectives.first(where: { $0.id == id }),
              objective.status == .available || objective.status == .active,
              room == nil || objective.definition.roomID == room else {
            return nil
        }
        return objective.definition
    }
}

