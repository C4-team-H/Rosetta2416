import Foundation

enum MissionID: String, Codable, CaseIterable, Sendable {
    case findLaboratory
    case restoreAI
    case repairEngine
    case retrieveCalibrationTools
    case continueEngineRepair
    case initiateLaunch
}

struct MissionState: Codable, Equatable, Sendable {
    let id: MissionID
    let title: String
    let targetRoomID: RoomID
    var activeChallengeID: String?
}
