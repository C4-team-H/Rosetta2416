import Foundation

struct AlbumBookState: Codable, Equatable, Sendable {
    var hasFailedDrawingBefore = false
    var hasReceivedHint = false
    var hasOpenedBook = false
    var isMarkerVisible = true
    var isMarkerPermanent = true
    var consecutiveFailuresByChallenge: [String: Int] = [:]

    enum CodingKeys: String, CodingKey {
        case hasFailedDrawingBefore
        case hasReceivedHint
        case hasOpenedBook
        case isMarkerVisible
        case isMarkerPermanent
        case consecutiveFailuresByChallenge
    }

    init(
        hasFailedDrawingBefore: Bool = false,
        hasReceivedHint: Bool = false,
        hasOpenedBook: Bool = false,
        isMarkerVisible: Bool = true,
        isMarkerPermanent: Bool = true,
        consecutiveFailuresByChallenge: [String: Int] = [:]
    ) {
        self.hasFailedDrawingBefore = hasFailedDrawingBefore
        self.hasReceivedHint = hasReceivedHint
        self.hasOpenedBook = hasOpenedBook
        self.isMarkerVisible = isMarkerVisible
        self.isMarkerPermanent = isMarkerPermanent
        self.consecutiveFailuresByChallenge = consecutiveFailuresByChallenge
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hasFailedDrawingBefore = try container.decodeIfPresent(Bool.self, forKey: .hasFailedDrawingBefore) ?? false
        hasReceivedHint = try container.decodeIfPresent(Bool.self, forKey: .hasReceivedHint) ?? false
        hasOpenedBook = try container.decodeIfPresent(Bool.self, forKey: .hasOpenedBook) ?? false
        isMarkerVisible = try container.decodeIfPresent(Bool.self, forKey: .isMarkerVisible) ?? true
        isMarkerPermanent = try container.decodeIfPresent(Bool.self, forKey: .isMarkerPermanent) ?? true
        consecutiveFailuresByChallenge = try container.decodeIfPresent([String: Int].self, forKey: .consecutiveFailuresByChallenge) ?? [:]
    }
}
