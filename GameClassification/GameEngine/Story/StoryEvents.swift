import Foundation

enum StoryEvent: Equatable, Sendable {
    case roomEntered(RoomID)
    case stationInteractionRequested(String)
    case drawingValidated(objectiveID: String, result: RecognitionResult)
    case drawingFailed
    case foodCompleted
    case energyDepleted
    case checkpointRetryRequested
    case newSession
}

enum StoryEffect: Equatable, Sendable {
    case objectiveCompleted(String)
    case chapterChanged(StoryChapter)
    case powerChanged(ShipPowerState)
    case checkpointReached(CheckpointID)
    case cutscene(StoryCutscene)
    case doorAccessChanged(RoomID, isUnlocked: Bool)
    case stationVisualChanged(String, ObjectiveStatus)
    case dialogue(DialogueTrigger)
    case interactionDenied(String)
    case mapNeedsRefresh
    case gameOver
    case victory
}

enum StoryCommand: Codable, Equatable, Sendable {
    case requestInteraction(commandID: UUID, stationID: String, playerID: String)
    case submitDrawing(commandID: UUID, objectiveID: String, drawingData: Data, playerID: String)
    case collect(commandID: UUID, itemID: String, playerID: String)

    var id: UUID {
        switch self {
        case let .requestInteraction(commandID, _, _),
             let .submitDrawing(commandID, _, _, _),
             let .collect(commandID, _, _):
            commandID
        }
    }
}
