import Foundation

@MainActor
struct StationVisibilitySystem {
    let storySystem: StoryProgressionSystem
    let isDebugEnabled: Bool

    static let kitchenInteractionID = "kitchen-food"

    func shouldShowStation(interactionID: String) -> Bool {
        if isDebugEnabled { return true }
        if interactionID == Self.kitchenInteractionID { return true }
        guard let activeObjective = storySystem.activeObjective else { return false }
        return interactionID == activeObjective.id
    }
}
