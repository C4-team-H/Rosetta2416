import Foundation

enum StoryChapter: String, Codable, CaseIterable, Sendable {
    case sleepingRoom
    case laboratory
    case engineInitial
    case storage
    case engineFinal
    case cockpit
    case victory

    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "enginePhaseOne": self = .engineInitial
        case "engineBlocked": self = .storage
        case "completed": self = .victory
        default:
            guard let chapter = Self(rawValue: value) else {
                throw DecodingError.dataCorruptedError(
                    in: try decoder.singleValueContainer(),
                    debugDescription: "Unknown story chapter: \(value)"
                )
            }
            self = chapter
        }
    }
}

enum ShipPowerState: String, Codable, Sendable {
    case off
    case basicPower
    case disrupted
    case fullyRestored

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = value == "emergency" ? .off : (Self(rawValue: value) ?? .off)
    }
}
