import CoreGraphics

struct PlayerState: Identifiable, Equatable {
    let id: String
    var name: String
    var worldPosition: CGPoint
    var isConnected: Bool
}
