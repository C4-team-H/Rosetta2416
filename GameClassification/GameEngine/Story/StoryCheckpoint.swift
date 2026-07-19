import Foundation

enum CheckpointID: String, Codable, CaseIterable, Sendable {
    case sleepingRoomStart
    case laboratoryEntered
    case laboratoryCompleted
    case engine10
    case engine40
    case engine60
    case advancedToolsAcquired
    case engine100
    case cockpitEntered

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "sleepingRoom": self = .sleepingRoomStart
        case "laboratory": self = .laboratoryEntered
        case "enginePhaseOne": self = .engine10
        case "engineDisruption": self = .engine40
        case "engineBlocked": self = .engine60
        case "storage": self = .advancedToolsAcquired
        case "engineFinal": self = .engine100
        case "cockpit": self = .cockpitEntered
        default: self = Self(rawValue: value) ?? .sleepingRoomStart
        }
    }
}
