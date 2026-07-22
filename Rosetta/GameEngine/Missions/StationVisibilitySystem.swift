import Foundation

enum StationVisibility: String, Codable, Equatable, Sendable {
    case hidden
    case worldOnly
    case mapOnly
    case worldAndMap

    var showsInWorld: Bool { self == .worldOnly || self == .worldAndMap }
    var showsOnMap: Bool { self == .mapOnly || self == .worldAndMap }
}

@MainActor
struct StationVisibilitySystem {
    let storySystem: StoryProgressionSystem
    let isDebugEnabled: Bool

    static let kitchenInteractionID = "kitchen-food"
    static let albumInteractionID = "album-book"

    func visibility(interactionID: String) -> StationVisibility {
        if isDebugEnabled { return .worldAndMap }
        if interactionID == Self.kitchenInteractionID { return .worldAndMap }
        if interactionID == Self.albumInteractionID { return .worldAndMap }
        if interactionID == storySystem.activeObjective?.id { return .worldAndMap }
        if storySystem.state.completedChallengeIDs.contains(interactionID),
           StoryConfiguration.definition(id: interactionID)?.persistsAsRepairedWorldProp == true {
            return .worldOnly
        }
        return .hidden
    }

    func shouldShowStation(interactionID: String) -> Bool {
        visibility(interactionID: interactionID).showsInWorld
    }

    func shouldShowOnMap(interactionID: String) -> Bool {
        visibility(interactionID: interactionID).showsOnMap
    }
}
