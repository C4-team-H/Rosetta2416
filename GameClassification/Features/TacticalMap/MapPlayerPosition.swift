import CoreGraphics

struct MapPlayerPosition: Identifiable, Equatable {
    let id: String
    let name: String
    let worldPosition: CGPoint
    let isLocalPlayer: Bool
    let isConnected: Bool
}
