import Foundation

extension StoryState {
    var isMainPowerOnline: Bool {
        powerState == .basicPower || powerState == .fullyRestored
    }

    // Album flags are projections into the nested state, never duplicate storage.
    var hasFailedDrawingBefore: Bool {
        get { albumBook.hasFailedDrawingBefore }
        set { albumBook.hasFailedDrawingBefore = newValue }
    }

    var hasReceivedAlbumHint: Bool {
        get { albumBook.hasReceivedHint }
        set { albumBook.hasReceivedHint = newValue }
    }

    var hasOpenedAlbumBook: Bool {
        get { albumBook.hasOpenedBook }
        set { albumBook.hasOpenedBook = newValue }
    }

}
