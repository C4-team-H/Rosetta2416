import CoreGraphics

/// Kept separate from gesture handling so zoom and pan can be enabled without changing map content.
struct MapViewportTransform: Equatable {
    var scale: CGFloat
    var offset: CGSize

    static let identity = MapViewportTransform(scale: 1, offset: .zero)
}
