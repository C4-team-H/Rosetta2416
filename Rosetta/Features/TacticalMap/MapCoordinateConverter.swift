import CoreGraphics

/// Converts bottom-left SpriteKit world coordinates into top-left SwiftUI map coordinates.
struct MapCoordinateConverter {
    let worldSize: CGSize
    let mapFrame: CGRect

    init(worldSize: CGSize, mapFrame: CGRect) {
        self.worldSize = worldSize
        self.mapFrame = mapFrame.standardized
    }

    /// Creates an aspect-fit map frame inside a viewport, preserving the requested padding.
    init(worldSize: CGSize, viewportSize: CGSize, padding: CGFloat) {
        guard worldSize.isValid, viewportSize.isValid else {
            self.init(worldSize: worldSize, mapFrame: .zero)
            return
        }

        let safePadding = max(0, padding)
        let availableWidth = max(0, viewportSize.width - safePadding * 2)
        let availableHeight = max(0, viewportSize.height - safePadding * 2)
        let scale = min(availableWidth / worldSize.width, availableHeight / worldSize.height)
        let fittedSize = CGSize(width: worldSize.width * scale, height: worldSize.height * scale)
        let origin = CGPoint(
            x: (viewportSize.width - fittedSize.width) / 2,
            y: (viewportSize.height - fittedSize.height) / 2
        )

        self.init(worldSize: worldSize, mapFrame: CGRect(origin: origin, size: fittedSize))
    }

    var scale: CGFloat {
        guard worldSize.isValid else { return 0 }
        return min(mapFrame.width / worldSize.width, mapFrame.height / worldSize.height)
    }

    func normalizedPosition(from worldPosition: CGPoint) -> CGPoint {
        guard worldSize.isValid, worldPosition.isFinite else {
            return CGPoint(x: 0.5, y: 0.5)
        }

        return CGPoint(
            x: (worldPosition.x / worldSize.width).clamped(to: 0...1),
            y: (worldPosition.y / worldSize.height).clamped(to: 0...1)
        )
    }

    func mapPosition(from worldPosition: CGPoint, edgeInset: CGFloat = 0) -> CGPoint {
        guard mapFrame.isValid else {
            return CGPoint(x: mapFrame.midX, y: mapFrame.midY)
        }

        let normalized = normalizedPosition(from: worldPosition)
        let rawPosition = CGPoint(
            x: mapFrame.minX + normalized.x * mapFrame.width,
            y: mapFrame.minY + (1 - normalized.y) * mapFrame.height
        )
        let inset = min(max(0, edgeInset), min(mapFrame.width, mapFrame.height) / 2)

        return CGPoint(
            x: rawPosition.x.clamped(to: (mapFrame.minX + inset)...(mapFrame.maxX - inset)),
            y: rawPosition.y.clamped(to: (mapFrame.minY + inset)...(mapFrame.maxY - inset))
        )
    }

    func mapRect(from worldRect: CGRect) -> CGRect {
        let standardizedRect = worldRect.standardized
        guard standardizedRect.isValid else { return .zero }

        let topLeft = mapPosition(from: CGPoint(x: standardizedRect.minX, y: standardizedRect.maxY))
        let bottomRight = mapPosition(from: CGPoint(x: standardizedRect.maxX, y: standardizedRect.minY))

        return CGRect(
            x: min(topLeft.x, bottomRight.x),
            y: min(topLeft.y, bottomRight.y),
            width: abs(bottomRight.x - topLeft.x),
            height: abs(bottomRight.y - topLeft.y)
        ).standardized
    }

    func mapPoints(from worldPoints: [CGPoint]) -> [CGPoint] {
        worldPoints.map { mapPosition(from: $0) }
    }
}

private extension BinaryFloatingPoint {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension CGRect {
    var isValid: Bool {
        !isNull && !isInfinite && width.isFinite && height.isFinite && width > 0 && height > 0
    }
}
