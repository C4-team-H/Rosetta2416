import CoreGraphics

extension CGSize {
    var isValid: Bool {
        width.isFinite && height.isFinite && width > 0 && height > 0
    }
}
