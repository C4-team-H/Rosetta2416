import Foundation

struct AlbumBookState: Codable, Equatable, Sendable {
    var hasFailedDrawingBefore = false
    var hasReceivedHint = false
    var hasOpenedBook = false
    var isMarkerVisible = false
    var isMarkerPermanent = false
}
