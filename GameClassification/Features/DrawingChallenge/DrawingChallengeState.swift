struct DrawingChallenge {
    let label: String
    let displayName: String
}

extension DrawingChallenge {
    static let enginePool: [DrawingChallenge] = [
        DrawingChallenge(label: "book", displayName: "BUKU"),
        DrawingChallenge(label: "alarm clock", displayName: "JAM WEKER"),
        DrawingChallenge(label: "computer monitor", displayName: "MONITOR"),
        DrawingChallenge(label: "door", displayName: "PINTU"),
        DrawingChallenge(label: "eyeglasses", displayName: "KACAMATA")
    ]

    // Lab memiliki 3 easel, masing-masing dengan objek tetap (tidak acak).
    // Urutan ini cocok dengan labEaselPositions di GameMapLayout.
    static let labEaselChallenges: [DrawingChallenge] = [
        DrawingChallenge(label: "butterfly", displayName: "KUPU-KUPU"),
        DrawingChallenge(label: "spider", displayName: "LABA-LABA"),
        DrawingChallenge(label: "snake", displayName: "ULAR")
    ]

    static let foodPool: [DrawingChallenge] = [
        DrawingChallenge(label: "banana", displayName: "PISANG"),
        DrawingChallenge(label: "apple", displayName: "APEL"),
        DrawingChallenge(label: "donut", displayName: "DONAT"),
        DrawingChallenge(label: "pizza", displayName: "PIZZA"),
        DrawingChallenge(label: "carrot", displayName: "WORTEL")
    ]
}
