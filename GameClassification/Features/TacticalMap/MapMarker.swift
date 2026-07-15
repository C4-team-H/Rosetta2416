import CoreGraphics
import Foundation

struct MapMarker: Identifiable, Equatable {
    let id: UUID
    let type: MapMarkerType
    let worldPosition: CGPoint
    let title: String?
    let isVisible: Bool

    init(
        id: UUID = UUID(),
        type: MapMarkerType,
        worldPosition: CGPoint,
        title: String? = nil,
        isVisible: Bool = true
    ) {
        self.id = id
        self.type = type
        self.worldPosition = worldPosition
        self.title = title
        self.isVisible = isVisible
    }

    func replacingType(with newType: MapMarkerType) -> MapMarker {
        MapMarker(
            id: id,
            type: newType,
            worldPosition: worldPosition,
            title: title,
            isVisible: isVisible
        )
    }
}
