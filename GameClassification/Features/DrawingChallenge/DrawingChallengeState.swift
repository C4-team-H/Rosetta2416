struct DrawingChallenge {
    let label: String
    let displayName: String
}

extension DrawingChallenge {
    static let all: [DrawingChallenge] = [
        DrawingChallenge(label: "book", displayName: "BUKU"),
        DrawingChallenge(label: "butterfly", displayName: "KUPU-KUPU"),
        DrawingChallenge(label: "cactus", displayName: "KAKTUS"),
        DrawingChallenge(label: "candle", displayName: "LILIN"),
        DrawingChallenge(label: "fish", displayName: "IKAN")
    ]
}
