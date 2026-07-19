import Foundation

struct AlbumBookSystem: Sendable {
    mutating func recordFirstDrawingFailure(in state: inout AlbumBookState) -> Bool {
        guard !state.hasFailedDrawingBefore else { return false }
        state.hasFailedDrawingBefore = true
        state.hasReceivedHint = true
        state.isMarkerVisible = true
        return true
    }

    mutating func openBook(in state: inout AlbumBookState) -> Bool {
        let isFirstOpen = !state.hasOpenedBook
        state.hasOpenedBook = true
        state.isMarkerVisible = true
        state.isMarkerPermanent = true
        return isFirstOpen
    }
}
