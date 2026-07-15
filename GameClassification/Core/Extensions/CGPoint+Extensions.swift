import CoreGraphics

extension CGPoint {
    var isFinite: Bool {
        x.isFinite && y.isFinite
    }
}
