import Foundation

struct AlbumBookSystem: Sendable {
    mutating func recordDrawingFailure(challengeID: String, in state: inout AlbumBookState) -> Bool {
        let count = (state.consecutiveFailuresByChallenge[challengeID] ?? 0) + 1
        state.consecutiveFailuresByChallenge[challengeID] = count
        if count >= 3 {
            state.consecutiveFailuresByChallenge[challengeID] = 0
            state.hasFailedDrawingBefore = true
            state.hasReceivedHint = true
            state.isMarkerVisible = true
            return true
        }
        return false
    }

    mutating func recordDrawingSuccess(challengeID: String, in state: inout AlbumBookState) {
        state.consecutiveFailuresByChallenge[challengeID] = 0
    }

    mutating func openBook(in state: inout AlbumBookState) -> Bool {
        let isFirstOpen = !state.hasOpenedBook
        state.hasOpenedBook = true
        state.isMarkerVisible = true
        state.isMarkerPermanent = true
        return isFirstOpen
    }
}
